"""Paperless parser: Tesseract builds the archive PDF, a vision model reads it.

See ../paperless-llm-ocr.nix for why and how it is set up. In short:

- Wins over paperless's Tesseract parser (score 20 against 10) for the
  same file types, and runs it first: the archive PDF, its text layer and
  the thumbnail stay Tesseract's.
- Then every page of that archive PDF (turned upright by Tesseract) is
  rendered at 200 dpi and sent to ollama; the model's text replaces
  Tesseract's as the document's content, cleaned of most of its markup.
- PDFs that bring their own text (GoodNotes) only go through Tesseract.
- If the model fails on any page, the document keeps Tesseract's text and
  gets the fallback tag. A later successful "Redo OCR" removes it.
- The model's raw answer is kept as <raw dir>/<document id>.md.

A parser is not told which document it parses. For a new document, the
result waits here until the consumer's "consumption finished" signal
brings the document; "Redo OCR" passes the stored original, from whose
path the document is found.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import re
import subprocess
import threading
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

from django.conf import settings

from documents.signals import document_consumption_finished
from documents.signals import document_consumption_started
from paperless.models import ModeChoices
from paperless.parsers.tesseract import RasterisedDocumentParser
from paperless.parsers.utils import is_born_digital_text

PDFTOPPM = "@pdftoppm@"
DPI = 200
PAGE_TIMEOUT = 600  # seconds per page, waiting in ollama's queue included

logger = logging.getLogger("paperless.parsers.llm_ocr")


def _config():
    """URL, model, fallback tag, raw dir; None if any is not set."""
    names = ("URL", "MODEL", "TAG", "RAW_DIR")
    values = [os.environ.get(f"PAPERLESS_LLM_OCR_{n}") for n in names]
    return values if all(values) else None


# --- Markup -------------------------------------------------------------
#
# LightOnOCR answers in Markdown with HTML tables. The content field feeds
# full-text search and paperless's AI, which sees only the first 4000
# characters, so tables become one line per row and other markup goes.
# Headings (#) and bold (**) stay. The raw answer is kept separately.

_TABLE = re.compile(r"<table\b.*?</table>", re.S | re.I)
_COMMENT = re.compile(r"<!--.*?-->", re.S)
_BR = re.compile(r"<br\s*/?>", re.I)
_DIV = re.compile(r"</?div\b[^>]*>", re.I)
_IMAGE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
_DOT_LEADER = re.compile(r"(?:\.\s?){5,}|…{2,}")
_BLANK_LINES = re.compile(r"\n[ \t]*\n(?:[ \t]*\n)+")
_TABLE_TAGS = {"table", "thead", "tbody", "tfoot", "tr", "td", "th", "br",
               "caption", "colgroup", "col"}


def _span(value):
    try:
        return max(1, int(value or 1))
    except ValueError:
        return 1


class _Table(HTMLParser):
    """Rows of (text, rowspan, colspan) from one <table>."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.cell = None
        self.spans = (1, 1)

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.rows.append([])
        elif tag in ("td", "th"):
            a = dict(attrs)
            self.cell = []
            self.spans = (_span(a.get("rowspan")), _span(a.get("colspan")))
        elif tag == "br":
            if self.cell is not None:
                self.cell.append(" / ")
        elif tag not in _TABLE_TAGS and self.cell is not None:
            # Not markup but text that looks like it: <name@example.org>
            self.cell.append(self.get_starttag_text())

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            if not self.rows:
                self.rows.append([])
            text = " ".join("".join(self.cell).split())
            self.rows[-1].append((text, *self.spans))
            self.cell = None

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)


def _grid(rows):
    """Lay the cells out so each stays in its column.

    A cell spanning rows is repeated in each of them, so the cells beside
    it do not shift left. One spanning columns appears once, followed by
    empty cells.
    """
    carried = {}  # column -> [rows left, text]
    out = []
    for row in rows:
        cells = list(row)
        line = []
        col = 0
        while cells or any(c >= col for c in carried):
            if col in carried:
                left, text = carried[col]
                line.append(text)
                if left > 1:
                    carried[col][0] -= 1
                else:
                    del carried[col]
                col += 1
            elif cells:
                text, rowspan, colspan = cells.pop(0)
                for i in range(colspan):
                    line.append(text if i == 0 else "")
                    if rowspan > 1:
                        carried[col] = [rowspan - 1, text if i == 0 else ""]
                    col += 1
            else:
                line.append("")
                col += 1
        while line and not line[-1]:
            line.pop()
        if line:
            out.append(line)
    return out


def _flatten_table(match):
    parser = _Table()
    parser.feed(match.group(0))
    parser.close()
    rows = _grid(parser.rows)
    return "\n" + "\n".join("| " + " | ".join(r) + " |" for r in rows) + "\n"


def clean(text):
    text = _COMMENT.sub("", text)  # the page markers of the raw text
    text = _TABLE.sub(_flatten_table, text)
    text = _BR.sub("\n", text)
    text = _DIV.sub("", text)
    text = _IMAGE.sub("", text)
    text = _DOT_LEADER.sub(" … ", text)
    text = _BLANK_LINES.sub("\n\n", text)
    return text.strip()


# --- The model ----------------------------------------------------------


def _render(pdf, out_dir):
    """The pages of pdf as JPEG files at DPI, in order."""
    out_dir.mkdir()
    subprocess.run(
        [PDFTOPPM, "-jpeg", "-r", str(DPI), str(pdf), str(out_dir / "p")],
        check=True,
        capture_output=True,
    )
    # pdftoppm pads the page number to the width of the page count
    return sorted(out_dir.glob("p-*.jpg"), key=lambda p: int(p.stem[2:]))


def _read_page(url, model, image):
    """The model's transcription of one page image."""
    body = {
        "model": model,
        "stream": False,
        # Without this the whole answer lands in message.thinking.
        "think": False,
        # Plain transcription: no instruction, as in the trial.
        "messages": [{
            "role": "user",
            "content": "",
            "images": [base64.b64encode(image.read_bytes()).decode()],
        }],
        "options": {
            "temperature": 0.2,
            "top_p": 0.9,
            "num_ctx": 16384,
            "num_predict": 6000,
        },
    }
    request = urllib.request.Request(
        f"{url}/api/chat",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=PAGE_TIMEOUT) as response:
        answer = json.load(response)
    if answer.get("done_reason") != "stop":
        # "length": stopped at num_predict, which in the trial meant the
        # model was repeating itself.
        raise RuntimeError(f"model stopped with {answer.get('done_reason')!r}")
    text = (answer.get("message") or {}).get("content", "").strip()
    seconds = answer.get("total_duration", 0) / 1e9
    logger.debug("%s: %d characters in %.1f s", image.name, len(text), seconds)
    return text


# --- Tag and raw text ---------------------------------------------------

# What the last parse in this thread left for the document it parsed:
# (raw text or None, whether it fell back to Tesseract).
_state = threading.local()


def _apply(document, raw, fell_back):
    from documents.models import Tag

    _, _, tag_name, raw_dir = _config()
    if fell_back:
        tag, _ = Tag.objects.get_or_create(
            name=tag_name,
            defaults={"matching_algorithm": Tag.MATCH_NONE},
        )
        document.tags.add(tag)
        logger.warning("Document %s: model failed, tagged %r", document.pk, tag_name)
    else:
        document.tags.remove(*Tag.objects.filter(name=tag_name))
    if raw is not None:
        directory = Path(raw_dir)
        directory.mkdir(parents=True, exist_ok=True)
        (directory / f"{document.pk}.md").write_text(raw)


def _on_started(**kwargs):
    _state.result = None


def _on_finished(document, **kwargs):
    result = getattr(_state, "result", None)
    _state.result = None
    if result is not None:
        _apply(document, *result)


document_consumption_started.connect(_on_started, weak=False)
document_consumption_finished.connect(_on_finished, weak=False)


def _stored_document(path):
    """The document whose stored original is path, if it is one."""
    from documents.models import Document

    try:
        name = Path(path).resolve().relative_to(settings.ORIGINALS_DIR.resolve())
    except ValueError:
        return None
    return Document.objects.filter(filename=str(name)).first()


# --- The parser ---------------------------------------------------------


class VisionModelDocumentParser(RasterisedDocumentParser):
    name = "Tesseract archive, text from a vision model in ollama"
    version = "1.0.0"
    author = "nix-config"
    url = "https://github.com/evelynandrist/nix-config"

    @classmethod
    def score(cls, mime_type, filename, path=None):
        if _config() is None:
            return None
        base = super().score(mime_type, filename, path)
        return None if base is None else base + 10

    def parse(self, document_path, mime_type, *, produce_archive=True):
        _state.result = None
        super().parse(document_path, mime_type, produce_archive=produce_archive)

        if self.settings.mode == ModeChoices.OFF:
            return
        if mime_type == "application/pdf" and is_born_digital_text(
            self.extract_text(None, document_path), document_path, log=self.log,
        ):
            self.log.debug("Has its own text, not sent to the model")
            return

        raw = None
        try:
            raw = self._read_with_model()
        except Exception as e:
            self.log.warning(f"Vision model failed, keeping Tesseract's text: {e!r}")
        if raw is not None:
            self.text = clean(raw)
        result = (raw, raw is None)

        document = _stored_document(document_path)
        if document is not None:
            # "Redo OCR": no consumption signals, the document is known.
            _apply(document, *result)
        else:
            _state.result = result

    def _read_with_model(self):
        url, model, _, _ = _config()
        tempdir = Path(self.tempdir)
        # The PDF ocrmypdf wrote, pages turned upright, whether or not it is
        # kept as the archive version.
        pdf = next(
            (p for p in (tempdir / "archive-fallback.pdf", tempdir / "archive.pdf")
             if p.exists()),
            None,
        )
        if pdf is None:
            raise RuntimeError("Tesseract left no PDF to render")
        pages = _render(pdf, tempdir / "llm-pages")
        if not pages:
            raise RuntimeError("no pages rendered")
        texts = []
        for number, image in enumerate(pages, 1):
            texts.append(f"<!-- page {number} -->\n\n{_read_page(url, model, image)}")
        self.log.info(f"Read {len(pages)} pages with {model}")
        return "\n\n".join(texts) + "\n"
