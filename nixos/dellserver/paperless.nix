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
#   export/    nightly export (01:30, before restic at 02:30): documents
#              plus a dump of the database, which restic could otherwise
#              catch in the middle of a write. Paperless is stopped while
#              the export runs.
#
# Accounts: `admin` (password from sops) is for administration only. Other
# users and the workflows that set the owner live in paperless's database
# and are created in the web UI.
#
# Barcode splitting is off on purpose until the backlog is in; it
# rasterises every page of every PDF.
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
    };
  };

  # allowedTCPPorts cannot restrict by source, hence the hand-written rule.
  # The name comes from /etc/hosts (../common/lan-hosts.nix).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s packardserver.internal.qwt.ch --dport ${toString port} -j nixos-fw-accept
  '';
}
