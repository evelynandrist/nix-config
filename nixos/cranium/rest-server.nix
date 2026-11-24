# restic rest-server: the backup target of all hosts
# (../common/cranium-backup.nix), at port 30080 as on the TrueNAS, reached
# through nginx on packardserver (backup.qwt.ch).
#
# --private-repos: each login only gets into the repository of its name.
# The logins are read from .htpasswd in the data folder, rest-server's
# default, where the TrueNAS app kept them too (seen 2026-11-24), so they
# come with the pool. Each host's login is its host name; cranium's own line
# is added there before the cutover (the cutover notes).
#
# The repositories are protected by the daily snapshots in pools.nix, kept
# 30 days.
#
# It runs as uid 568, the owner of the repositories (pool-access.nix).
{ config, lib, pkgs, ... }:
let
  dataDir = "/mnt/Neocortex/Backups/restic";
in {
  services.restic.server = {
    enable = true;
    listenAddress = "30080";
    inherit dataDir;
    # not the module's privateRepos, which chowns .htpasswd (pool-access.nix)
    extraFlags = [ "--private-repos" ];
  };

  systemd.services.restic-rest-server.unitConfig.RequiresMountsFor = [ dataDir ];

  networking.firewall.allowedTCPPorts = [ 30080 ];
}
