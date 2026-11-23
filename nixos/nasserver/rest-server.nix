# restic rest-server: the backup target of all hosts
# (../common/truenas-backup.nix), at port 30080 as on the TrueNAS, reached
# through nginx on packardserver (backup.qwt.ch).
#
# --private-repos: each login only gets into the repository of its name.
# The logins are read from .htpasswd in the data folder, rest-server's
# default. If the TrueNAS app kept them there, they come with the data;
# otherwise copy its file there at the cutover (see the rehearsal).
#
# The repositories are protected by the daily snapshots in pools.nix, kept
# 30 days.
#
# Until the owners are changed it runs as uid 568 (truenas-owners.nix).
{ config, lib, pkgs, ... }:
let
  dataDir = "/mnt/Neocortex/Backups/restic";
in {
  services.restic.server = {
    enable = true;
    listenAddress = "30080";
    inherit dataDir;
    privateRepos = true;
  };

  users.users.restic.extraGroups = [ "pools" ];

  systemd.services.restic-rest-server.unitConfig.RequiresMountsFor = [ dataDir ];

  networking.firewall.allowedTCPPorts = [ 30080 ];
}
