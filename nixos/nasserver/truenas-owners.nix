# Until the owners on the pools are changed: the last step of the move,
# once Evelyn has decided to stay on NixOS. Changing owners is the first
# thing that writes to the data on the pools; after it, going back to
# TrueNAS needs the owners set back.
#
# On the TrueNAS, the apps ran as one shared user, `apps` (uid 568). Here
# each service has its own. Immich has 568 itself (immich.nix), so the
# photos stay as they are. What else 568 owns stays shared with Immich
# until the change, which this file does:
#   - the rest-server runs as uid 568, not as its own user `restic`;
#   - nothing chowns or chmods the pools: the modules of the rest-server
#     and Immich would, at every boot.
#
# The change, with the services stopped (assumes 568 owned the
# repositories, see the rehearsal):
#   sudo systemctl stop restic-rest-server.socket restic-rest-server immich-server
#   sudo chown -R --from=568 restic:restic /mnt/Neocortex/Backups/restic
#   # anything else of 568's, outside the photos, gets the owner of its service:
#   sudo find /mnt/Neocortex -path /mnt/Neocortex/Photos -prune -o -uid 568 -print
# then remove this file and its import in configuration.nix, and switch.
# The modules then set the folders' modes: the library 0700, the
# repositories' folder 0700 (user restic's home).
{ config, lib, ... }: {
  systemd.services.restic-rest-server.serviceConfig = {
    User = lib.mkForce "immich";
    Group = lib.mkForce "immich";
  };
  # The module makes the data folder the home of `restic` (chown, chmod) and,
  # with privateRepos, chowns .htpasswd to it. rest-server reads .htpasswd
  # from the data folder by itself, so the flag alone does the same.
  users.users.restic.createHome = lib.mkForce false;
  services.restic.server = {
    privateRepos = lib.mkForce false;
    extraFlags = [ "--private-repos" ];
  };

  # chmod 0700 of the library at every boot
  systemd.tmpfiles.settings.immich = lib.mkForce { };
}
