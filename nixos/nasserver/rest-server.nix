# restic rest-server: the backup target of all hosts
# (../common/truenas-backup.nix), at port 30080 as on the TrueNAS, reached
# through nginx on packardserver (backup.qwt.ch).
#
# --private-repos: each login only gets into the repository of its name.
# The logins are the .htpasswd in the data folder, which the TrueNAS app
# kept there too, so they come with the data. If it is not there, it is in
# the app's own folder on Thalamus/Apps: copy it next to the repositories.
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
