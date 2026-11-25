# Paperless-ngx: the document archive.
#
# Reached as https://paperless.internal.qwt.ch through nginx on
# packardserver (LAN and VPN only). Nothing else may connect: the port is
# open for packardserver alone.
#
# State, all in /persist/data/paperless (in the nightly restic backup):
#   media/     the documents
#   consume/   drop files here; paperless imports and then deletes them.
#              Subfolders become tags: consume/evelyn/school/kanti/bio/x.pdf
#              gets the tags evelyn, school, kanti and bio.
#              Folders named single_sheets are not imported: their PDFs
#              are cut into one document per sheet first, see
#              paperless-single-sheets.nix.
#   export/    nightly export (01:30, before restic at 02:30): documents
#              plus a dump of the database, which restic could otherwise
#              catch in the middle of a write. Paperless is stopped while
#              the export runs.
#
# Accounts: `admin` (password from sops) is for administration only. Other
# users and the workflows that set the owner live in paperless's database
# and are created in the web UI.
#
# Barcode splitting is on: a page whose barcode reads PATCHT separates two
# documents and is thrown away. Paperless keeps the split documents, not
# the PDF the scanner sent, so a wrong split can only be redone from paper.
# It rasterises every page of every PDF, which makes large imports slow.
#
# The text of scans comes from a vision model on this machine, with
# Tesseract as the fallback, see paperless-llm-ocr.nix.
#
# The scanner writes into consume/ over SMB, see samba.nix.
#
# Manage:  sudo paperless-manage <command>
{ config, ... }:
let
  dataDir = "/persist/data/paperless";
  port = 28981;
in {
  sops.secrets."paperless/admin_password" = { };

  services.paperless = {
    enable = true;
    inherit dataDir port;
    address = "0.0.0.0";
    passwordFile = config.sops.secrets."paperless/admin_password".path;

    # null = Tesseract with all languages, as built by the binary cache. A
    # list here means compiling tesseract, ocrmypdf and paperless locally.
    tesseractLanguages = null;

    exporter.enable = true;

    settings = {
      PAPERLESS_URL = "https://paperless.internal.qwt.ch";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;
      # Since 3.0 a file whose content is already in the archive is imported
      # a second time unless this is set. With it, the copy is removed from
      # the consume folder instead. Documents in the trash count too: empty
      # the trash before importing something again.
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      # How sure the OCR must be of a page's direction to turn it (default
      # 12). Scanned landscape pages were left sideways at 7.6 to 9.7, and
      # no upright page was misjudged anywhere near that.
      PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD = 7;

      # The built-in AI, for title, date and document type. It talks to
      # ollama on the nixbook (../../darwin/nixbook/ollama.nix), so nothing
      # leaves the LAN. No embedding backend: that would build a vector
      # index of every document each night, which nothing here needs.
      # Until a workflow uses it, it only answers the "Suggest" button on
      # a document, which shows the result and changes nothing.
      PAPERLESS_AI_ENABLED = true;
      # ollama's OpenAI-compatible endpoint, not the "ollama" backend: that
      # one cannot turn the model's thinking off (llama-index-llms-ollama
      # 0.11.0 drops paperless's think=False), and with thinking one
      # document took 285 s instead of 9 to 13, longer than paperless's
      # own timeout of 120 s. Here reasoning_effort turns it off.
      PAPERLESS_AI_LLM_BACKEND = "openai-like";
      PAPERLESS_AI_LLM_ENDPOINT = "http://nixbook.internal.qwt.ch:11434/v1";
      PAPERLESS_AI_LLM_MODEL = "qwen3.5:9b";
      PAPERLESS_AI_LLM_EXTRA_PARAMS = { reasoning_effort = "none"; };
      # The AI's prompt is fixed: it gets the text and the stored file name,
      # nothing else. So the stored name is the original one instead of
      # 0000123.pdf, which hands it the subject and topic of the GoodNotes
      # files ("bio ~ Zoologie ~ x.pdf"). A document already in the archive
      # is renamed when it is next saved, or all at once with
      # `sudo paperless-manage document_renamer`.
      PAPERLESS_FILENAME_FORMAT = "{{ original_name }}";
    };
  };

  # allowedTCPPorts cannot restrict by source, hence the hand-written rule.
  # The name comes from /etc/hosts (../common/lan-hosts.nix).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s packardserver.internal.qwt.ch --dport ${toString port} -j nixos-fw-accept
  '';
}
