# Nightly restic backup to the rest-server on cranium, the NAS.
#
# Not imported by default: a host imports this file and sets
# services.restic.backups.cranium.paths (and excludes) itself.
#
# The rest-server runs with --private-repos, so a host only gets into its own
# repository (/<hostname>/). It is not append-only: every host prunes its own
# old snapshots after the backup. What protects against a host that deletes
# its repository (compromised, or a mistake) are the ZFS snapshots of the
# dataset on cranium, kept for 30 days.
#
# It is reached through nginx on packardserver (backup.qwt.ch), nothing is
# mounted. Secrets, per host, in secrets/secrets.yaml:
#   backup/<hostname>/repo_password   encrypts the repository
#   backup/<hostname>/rest_password   the host's login on the rest-server
#   backup/ha_webhook_id              Home Assistant webhook for failures
#
# Run now:  sudo systemctl start restic-backups-cranium.service
# Inspect:  sudo restic-cranium snapshots
# Restore:  sudo restic-cranium restore latest --target /tmp/restore --include /persist/data/...
{ config, lib, pkgs, ... }:
let
  host = config.networking.hostName;
  secret = name: "backup/${host}/${name}";
in {
  sops.secrets = {
    ${secret "repo_password"} = { };
    ${secret "rest_password"} = { };
    "backup/ha_webhook_id" = { };
  };

  # Read twice: by systemd (EnvironmentFile) for the nightly run and by the
  # shell for the restic-cranium command. The quotes keep the shell from
  # interpreting spaces, $ and the like in the password; systemd drops them.
  # The password itself must not contain a single quote.
  sops.templates."restic-cranium.env".content = ''
    RESTIC_REST_USERNAME=${host}
    RESTIC_REST_PASSWORD='${config.sops.placeholder.${secret "rest_password"}}'
  '';

  services.restic.backups.cranium = {
    repository = "rest:https://backup.qwt.ch/${host}/";
    passwordFile = config.sops.secrets.${secret "repo_password"}.path;
    environmentFile = config.sops.templates."restic-cranium.env".path;
    initialize = true;
    exclude = [
      "**/.cache"
    ];
    timerConfig = {
      OnCalendar = "*-*-* 02:30:00";
      RandomizedDelaySec = "20min";
      # a machine that was off at 02:30 catches up after boot
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
    ];
    # Verify the repository structure after every run (metadata only, the
    # pack files are not downloaded). A broken repository then shows up as a
    # failed unit and a notification instead of at restore time.
    runCheck = true;
  };

  # Push notification to the phone when a backup fails. The webhook triggers
  # an automation in Home Assistant, which knows the notify service.
  systemd.services.restic-backups-cranium.unitConfig.OnFailure = [ "restic-cranium-failed.service" ];
  systemd.services.restic-cranium-failed = {
    description = "Report a failed backup to cranium to Home Assistant";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.curl}/bin/curl -fsS --retry 5 --retry-delay 30 --retry-all-errors \
        -X POST -H 'Content-Type: application/json' \
        -d '{"host": "${host}"}' \
        "https://home.qwt.ch/api/webhook/$(cat ${config.sops.secrets."backup/ha_webhook_id".path})"
    '';
  };
}
