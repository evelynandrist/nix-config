# Radicale: calendars and contacts (CalDAV/CardDAV).
#
# Moved here from the NAS so that calendar sync depends on one always-on
# machine only. Reached as radicale.internal.qwt.ch (site in nginx.nix).
#
# State, all in /persist/data/radicale (owner radicale:radicale):
#   collections/   the calendars and address books
#   users          htpasswd file with bcrypt hashes; not in the repo.
#                  Add or change a login:
#                    nix shell nixpkgs#apacheHttpd -c htpasswd -B /persist/data/radicale/users <name>
{ config, lib, pkgs, ... }:
let
  dataDir = "/persist/data/radicale";
in {
  services.radicale = {
    enable = true;
    settings = {
      # nginx is the only client
      server.hosts = [ "127.0.0.1:5232" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "${dataDir}/users";
        htpasswd_encryption = "bcrypt";
      };
      storage.filesystem_folder = "${dataDir}/collections";
    };
  };

  # The unit only gets write access to the collections folder, and fails to
  # start if that folder is missing.
  systemd.tmpfiles.rules = [
    "d '${dataDir}' 0750 radicale radicale - -"
    "d '${dataDir}/collections' 0750 radicale radicale - -"
  ];
}
