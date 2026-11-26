# Paperless reads scans with a vision model instead of Tesseract alone.
#
# Tesseract (deu+eng) fails on handwriting, tables and logos. A trial on
# 13 documents chose LightOnOCR-3-4B (Q6_K): handwriting nearly word for
# word, real tables, tick boxes, about 17 s per page on the RTX 3060. It
# runs in ollama on this machine (ollama.nix), so nothing leaves it.
#
# The bridge is a parser plugin (paperless-llm-ocr/): Tesseract still
# builds the archive PDF, its text layer and the thumbnail; the plugin
# sends the archive's pages to the model and puts the model's text into
# the document's content, which feeds search and paperless's AI.
#
# - Only documents imported from now on, and "Redo OCR". PDFs with their
#   own text (GoodNotes) only go through Tesseract, as before.
# - Content is cleaned: tables become one line per row, cells joined by
#   " | ", merged cells kept in their column; other HTML, image
#   placeholders and dot leaders go; headings and bold stay. The AI only
#   reads the first 4000 characters, and HTML tables took a quarter of the
#   text, up to half on table pages.
# - The model's raw answer, with page markers and full tables, is kept in
#   ${rawDir}/<document id>.md, for later uses that need the structure.
# - A page whose answer reaches the length limit (num_predict) keeps the
#   model's text up to where it starts repeating itself. Sheet music does
#   this, the model writes out notes until the limit; so did 16 of the
#   first 1124 pages. The whole answer stays in the raw file, its page
#   marker says it was cut; journalctl shows document and page.
# - If the model fails (ollama down, model missing), or a cut page is
#   left empty, the document gets Tesseract's text for those pages and the
#   tag `${tag}`. Run "Redo OCR" on it later; a successful run removes the
#   tag.
# - Long documents are not cut short: the worker's time limit is raised
#   from 30 minutes to 2 hours, about 350 pages.
#
# The model is a community conversion on ollama.com, pulled by tag.
# ollama-ocr-model pulls it only when it is missing (not at every start, as
# services.ollama.loadModels would) and compares its digest with the one
# below, the version tested in the trial. On a mismatch it removes the
# model and fails, Home Assistant reports it, and documents fall back to
# Tesseract with the tag until the new upload is checked and its digest
# put here.
#
# Check:   journalctl -u paperless-task-queue | grep -i 'vision model\|pages with'
#          journalctl -u ollama-ocr-model -b
# Turn off: remove this file from the imports; paperless uses Tesseract
#          alone again.
{ config, lib, pkgs, ... }:
let
  ollama = config.services.ollama;
  api = "http://${ollama.host}:${toString ollama.port}";
  rawDir = "${config.services.paperless.dataDir}/ocr-raw";
  tag = "ocr-fallback";

  # LightOnOCR-3-4B, quantised Q6_K
  model = "richardyoung/lightonocr-3-4b:Q6_K";
  # sha256 of its manifest; `ollama list` shows the first 12 characters
  digest = "70ca464ec2010f730c1fd74fe378739e8242d5924c6eb73af79a9e19bd4c54ed";
in {
  imports = [ ./ollama.nix ];

  services.paperless = {
    extraPythonPackages = ps: [ (ps.callPackage ./paperless-llm-ocr { }) ];
    settings = {
      # read by the plugin; without them it stays out of the way
      PAPERLESS_LLM_OCR_URL = api;
      PAPERLESS_LLM_OCR_MODEL = model;
      PAPERLESS_LLM_OCR_TAG = tag;
      PAPERLESS_LLM_OCR_RAW_DIR = rawDir;
      PAPERLESS_WORKER_TIMEOUT = 7200;
    };
  };

  # Not required: without ollama documents still come in, with the tag.
  systemd.services.paperless-task-queue = {
    wants = [ "ollama.service" ];
    after = [ "ollama.service" ];
  };

  systemd.services.ollama-ocr-model = {
    description = "Pull the OCR model into ollama if missing, check its digest";
    wantedBy = [ "multi-user.target" ];
    requires = [ "ollama.service" ];
    wants = [ "network-online.target" ];
    after = [ "ollama.service" "network-online.target" ];
    unitConfig.OnFailure = [ "ha-notify-failed@%n.service" ];
    path = [ pkgs.curl pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      DynamicUser = true;
    };
    script = ''
      for _ in $(seq 60); do
        curl -sf ${api}/api/version >/dev/null && break
        sleep 1
      done
      body=$(jq -cn --arg m ${lib.escapeShellArg model} '{model: $m, stream: false}')
      installed() {
        curl -sf ${api}/api/tags \
          | jq -r --arg m ${lib.escapeShellArg model} '.models[] | select(.name == $m) | .digest'
      }
      if [ -z "$(installed)" ]; then
        # waits until the download is complete; answers {"status":"success"}
        curl -sS ${api}/api/pull -d "$body" | jq -e '.status == "success"'
      fi
      have=$(installed)
      if [ "$have" != ${digest} ]; then
        echo "${model} has digest '$have', expected ${digest}: removed" >&2
        curl -sS -X DELETE ${api}/api/delete -d "$body" || true
        exit 1
      fi
      echo "${model} present, digest ${digest}"
    '';
  };
}
