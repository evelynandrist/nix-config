{ config, lib, pkgs, ... }:
let
  local = config.services.restic.backups.minecraft;
  cranium = config.services.restic.backups.cranium;

  # Second repository of this host on the rest-server, next to the general
  # one: same login, same password, but nothing is ever forgotten in it.
  archiveEnv = {
    RESTIC_REPOSITORY = "rest:https://backup.qwt.ch/${config.networking.hostName}/minecraft/";
    RESTIC_PASSWORD_FILE = cranium.passwordFile;
  };

  # sudo restic-minecraft-archive snapshots / mount / restore ...
  archiveWrapper = pkgs.writeShellScriptBin "restic-minecraft-archive" ''
    set -a
    . ${cranium.environmentFile}
    set +a
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") archiveEnv)}
    exec ${pkgs.restic}/bin/restic "$@"
  '';
in {
  imports = [ ../common/cranium-backup.nix ];

  # All state lives in /persist (impermanence).
  services.restic.backups.cranium = {
    paths = [ "/persist" ];
    exclude = [
      # Minecraft has its own way to cranium, see below: not the live
      # world (it would be copied while the server writes to it), and not the
      # local restic repository as plain files either.
      "/persist/data/minecraft-servers"
      "/persist/backups/minecraft"
    ];
  };

  # vaultwarden: services.vaultwarden.backupDir already writes a consistent
  # sqlite dump to /persist/data/vaultwarden every night at 23:00.

  #############################################################################
  #                       Minecraft archive on cranium                        #
  #############################################################################

  # Every night, the snapshots of the local hourly repository (minecraft.nix)
  # that cranium does not have yet are copied over, as snapshots: the
  # archive ends up with one per hour, without pausing the world a second
  # time. The local repository only keeps two weeks; the archive keeps
  # everything, which is what a timelapse gets rendered from later.
  # A day of play adds ~200 MB, a quiet day a few MB (measured 2026-11).
  systemd.services.restic-minecraft-archive = {
    description = "Copy the local minecraft snapshots to cranium";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.OnFailure = [ "restic-cranium-failed.service" ];
    environment = archiveEnv // {
      RESTIC_FROM_REPOSITORY = local.repository;
      RESTIC_FROM_PASSWORD_FILE = local.passwordFile;
      RESTIC_CACHE_DIR = "/var/cache/restic-minecraft-archive";
    };
    path = [ pkgs.restic ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = cranium.environmentFile;
      CacheDirectory = "restic-minecraft-archive";
    };
    script = ''
      # Same chunker parameters as the local repository, so that chunks are
      # recognised as the same ones on both sides.
      restic cat config > /dev/null 2>&1 || restic init --copy-chunker-params

      # --retry-lock: the local repository is locked while its own prune runs
      restic copy --retry-lock 15m
      restic check --retry-lock 15m
    '';
  };
  systemd.timers.restic-minecraft-archive = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # after the 03:00 snapshot, before the 04:30 restart
      OnCalendar = "*-*-* 03:10:00 Europe/Zurich";
      Persistent = true;
    };
  };

  # The hourly backup waits while the copy runs (the first one takes a
  # while), its prune could not lock the repository anyway. A running oneshot
  # unit holds back units that are ordered after it.
  systemd.services.restic-backups-minecraft.after = [ "restic-minecraft-archive.service" ];

  environment.systemPackages = [ archiveWrapper ];
}
