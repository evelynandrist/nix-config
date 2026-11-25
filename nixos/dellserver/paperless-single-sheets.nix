# One document per sheet, for a stack of one-sheet documents fed through
# the scanner in one go.
#
# The scanner profile "single sheets" scans both sides, keeps blank pages
# and saves the whole stack as one PDF to consume/<owner>/single_sheets/.
# Paperless ignores folders of that name. This service takes each PDF
# there, cuts it every 2 pages (front and back of one sheet), drops the
# pages that are blank, and puts the pieces into
# consume/<owner>/scansnap/loose_sheets/, where paperless imports them:
#
#   consume/evelyn/single_sheets/scan.pdf
#     ->  consume/evelyn/scansnap/loose_sheets/scan-001.pdf
#         consume/evelyn/scansnap/loose_sheets/scan-002.pdf ...
#
# The folders become tags (paperless.nix): the owner, `scansnap`, which
# every document from the scanner carries, and `loose_sheets`. (What the
# scanner writes to consume/evelyn/bulk_scan gets `scansnap` from a
# workflow in paperless's web UI instead.)
#
# The scanner's PDF is then moved to single_sheets/done/ and deleted after
# 30 days; a PDF that could not be cut goes to single_sheets/failed/ and
# stays (journalctl -u paperless-single-sheets says why).
#
# A page counts as blank when less than 0.005 % of it is dark, measured
# without the outer 8 % on each side (punch holes, shadows at the edge).
# Measured on a real stack: blank backs 0.001 % or less, the faintest page
# with content 0.011 %.
# To see what would be done with a PDF, without changing anything:
#
#   sudo -u paperless paperless-single-sheets --check <file.pdf>...
{ config, pkgs, ... }:
let
  consumeDir = config.services.paperless.consumptionDir;
  folder = "single_sheets";
  # Where the pieces go, under consume/<owner>/; each folder is a tag.
  target = "scansnap/loose_sheets";
  # consume/<owner>/single_sheets is watched for each of these.
  owners = [ "evelyn" ];
  user = config.services.paperless.user;

  splitter = pkgs.writers.writePython3Bin "paperless-single-sheets" {
    libraries = with pkgs.python3Packages; [ pikepdf pillow ];
    flakeIgnore = [ "E501" ];
  } ''
    import subprocess
    import sys
    import tempfile
    import time
    from pathlib import Path

    import pikepdf
    from PIL import Image

    FOLDER = "${folder}"
    TARGET = "${target}"
    PDFTOPPM = "${pkgs.poppler-utils}/bin/pdftoppm"
    MARGIN = 0.08  # of width and height, left out on each side
    DARK = 128  # grey values below this count as dark (0 black, 255 white)
    BLANK_BELOW = 0.00005  # share of dark pixels under which a page is blank
    STABLE_SECONDS = 15  # no change for this long: the scanner is done writing


    def dark_share(pdf, page):
        """Share of dark pixels on a page (1-based), margins left out."""
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "page"
            subprocess.run(
                [PDFTOPPM, "-gray", "-r", "50", "-f", str(page), "-l", str(page),
                 "-singlefile", str(pdf), str(out)],
                check=True,
            )
            with Image.open(out.with_suffix(".pgm")) as img:
                w, h = img.size
                box = (int(w * MARGIN), int(h * MARGIN),
                       int(w * (1 - MARGIN)), int(h * (1 - MARGIN)))
                hist = img.convert("L").crop(box).histogram()
        return sum(hist[:DARK]) / max(sum(hist), 1)


    def plan(pdf):
        """Per sheet, the list of (page number, dark share, kept)."""
        with pikepdf.open(pdf) as doc:
            count = len(doc.pages)
        sheets = []
        for first in range(1, count + 1, 2):
            sheet = []
            for page in range(first, min(first + 2, count + 1)):
                share = dark_share(pdf, page)
                sheet.append((page, share, share >= BLANK_BELOW))
            sheets.append(sheet)
        return sheets


    def report(pdf, sheets):
        print(f"{pdf}: {sum(len(s) for s in sheets)} pages")
        for number, sheet in enumerate(sheets, 1):
            pages = ", ".join(
                f"page {page} {share:.3%} {'kept' if kept else 'blank'}"
                for page, share, kept in sheet
            )
            if not any(kept for _, _, kept in sheet):
                pages += "  (whole sheet dropped)"
            print(f"  sheet {number:3}: {pages}")


    def split(pdf):
        """Cut pdf into one file per sheet in consume/<owner>/TARGET."""
        sheets = plan(pdf)
        report(pdf, sheets)
        target = pdf.parent.parent / TARGET
        target.mkdir(parents=True, exist_ok=True)
        tmp = pdf.parent / ".tmp"
        tmp.mkdir(exist_ok=True)
        pieces = []
        with pikepdf.open(pdf) as doc:
            for number, sheet in enumerate(sheets, 1):
                keep = [page for page, _, kept in sheet if kept]
                if not keep:
                    continue
                piece = pikepdf.new()
                for page in keep:
                    piece.pages.append(doc.pages[page - 1])
                path = tmp / f"{pdf.stem}-{number:03}.pdf"
                piece.save(path)
                pieces.append(path)
        # Only now into the consume folder, complete files and all at once.
        for path in pieces:
            path.rename(target / path.name)
        print(f"  {len(pieces)} documents to {target}")


    def wait_until_stable(pdf):
        while time.time() - pdf.stat().st_mtime < STABLE_SECONDS:
            time.sleep(2)


    def move(pdf, name):
        folder = pdf.parent / name
        folder.mkdir(exist_ok=True)
        pdf.rename(folder / f"{time.strftime('%Y%m%d-%H%M%S')}_{pdf.name}")


    def main():
        if len(sys.argv) >= 3 and sys.argv[1] == "--check":
            for arg in sys.argv[2:]:
                report(arg, plan(Path(arg)))
            return
        if len(sys.argv) != 2:
            sys.exit("usage: paperless-single-sheets <consume folder> | --check <file.pdf>...")

        for pdf in sorted(Path(sys.argv[1]).glob(f"*/{FOLDER}/*.pdf")):
            try:
                wait_until_stable(pdf)
                split(pdf)
            except Exception as e:
                print(f"{pdf}: failed: {e!r}", file=sys.stderr)
                move(pdf, "failed")
            else:
                move(pdf, "done")


    main()
  '';
in {
  # Matched by folder name, at any depth.
  services.paperless.settings.PAPERLESS_CONSUMER_IGNORE_DIRS = [ folder ];

  environment.systemPackages = [ splitter ];

  # Starts the service whenever a PDF lies in a single_sheets folder, and
  # again after it has run if one is still (or again) there. The folders are
  # named one by one: systemd only watches a path up to its first wildcard,
  # so consume/*/single_sheets/*.pdf would never notice a new file.
  systemd.paths.paperless-single-sheets = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExistsGlob =
      map (owner: "${consumeDir}/${owner}/${folder}/*.pdf") owners;
  };

  systemd.services.paperless-single-sheets = {
    description = "Cut single-sheet scans into one document per sheet";
    serviceConfig = {
      Type = "oneshot";
      User = user;
      ExecStart = "${splitter}/bin/paperless-single-sheets ${consumeDir}";
      UMask = "0027";
      ProtectSystem = "strict";
      ReadWritePaths = [ consumeDir ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # The watched folders must exist; done/ is emptied of files older than
  # 30 days.
  systemd.tmpfiles.rules =
    map (owner: "d ${consumeDir}/${owner}/${folder} 0750 ${user} ${user} -") owners
    ++ [ "e ${consumeDir}/*/${folder}/done - - - 30d" ];
}
