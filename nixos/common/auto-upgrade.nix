# Every host follows main on GitHub by itself.
#
# dellserver bumps flake.lock once a week on the branch auto/flake-update
# (nixos/dellserver/flake-update.nix), which Evelyn merges. This pulls main every night
# and switches to it, so anything pushed to main goes live the next night.
# There are no automatic reboots: a new kernel waits for the next manual one.
#
# A system deployed by hand from something that is not on main (uncommitted
# or unpushed changes) is left alone for three days, so a test deploy
# survives the night. After that the host goes back to main, pushed or not,
# so it can't fall behind on updates because of a forgotten push.
#
# Home Assistant gets a webhook (and sends a push notification) when the
# upgrade fails, or when units are failed a few minutes after a switch. The
# payload is {"host": ..., "message": ...}, where message is the list of
# failed units, separated by spaces. Secret in secrets/secrets.yaml:
#   upgrade/ha_webhook_id
#
# Run now:   sudo systemctl start nixos-upgrade.service
# Undo:      sudo nixos-rebuild switch --rollback, and revert the commit on
#            main, otherwise the next night brings it back
# Pause:     sudo systemctl stop nixos-upgrade.timer (until the next boot)
{ config, lib, pkgs, inputs, ... }:
let
  host = config.networking.hostName;
  repo = "evelynandrist/nix-config";
  before = "/run/nixos-upgrade-before";

  # Decides whether tonight's upgrade runs: exit 0 runs it, exit 1 skips it
  # without counting as a failure.
  guard = pkgs.writeShellScript "nixos-upgrade-guard" ''
    # lets the health check tell whether this run switched to something new
    readlink /run/current-system > ${before}

    # The profile, not the running system: on nixpad the two differ between
    # an upgrade and the next boot.
    profile=/nix/var/nix/profiles/system
    age=$(( $(date +%s) - $(stat -c %Y "$profile") ))
    if [ "$age" -ge $(( 3 * 24 * 3600 )) ]; then
      exit 0
    fi

    # empty when it was built from a tree with uncommitted changes
    rev=$("$profile/sw/bin/nixos-version" --configuration-revision 2>/dev/null || true)
    if [ -n "$rev" ]; then
      response=$(${pkgs.curl}/bin/curl -s --max-time 30 -w '\n%{http_code}' \
        "https://api.github.com/repos/${repo}/compare/main...$rev" || true)
      code=''${response##*$'\n'}
      status=$(printf '%s' "''${response%$'\n'*}" | ${pkgs.jq}/bin/jq -r '.status // empty' 2>/dev/null || true)
      case "$code:$status" in
        200:behind | 200:identical) exit 0 ;; # the commit is on main
        200:* | 404:*) ;;                     # ahead of main, or never pushed
        *) exit 0 ;;                          # GitHub unreachable: don't hold back updates for that
      esac
    fi

    echo "The current system was deployed by hand less than three days ago and is not on main, skipping the upgrade."
    exit 1
  '';

  failedUnits = "systemctl list-units --failed --plain --no-legend | cut -d' ' -f1 | paste -sd' '";

  notify = pkgs.writeShellScript "nixos-upgrade-notify" ''
    payload=$(${pkgs.jq}/bin/jq -cn --arg host ${host} --arg message "$1" \
      '{host: $host, message: $message}')
    ${pkgs.curl}/bin/curl -fsS --retry 5 --retry-delay 30 --retry-all-errors \
      -X POST -H 'Content-Type: application/json' -d "$payload" \
      "https://home.qwt.ch/api/webhook/$(cat ${config.sops.secrets."upgrade/ha_webhook_id".path})"
  '';
in {
  sops.secrets."upgrade/ha_webhook_id" = { };

  system.autoUpgrade = {
    enable = true;
    flake = "github:${repo}";
    # after the backup (02:30), before the Minecraft restart on nixserver (04:30)
    dates = lib.mkDefault "04:00";
    operation = lib.mkDefault "switch";
    allowReboot = false;
  };

  # The commit the system was built from, unset for a tree with uncommitted
  # changes. The guard reads it back through nixos-version.
  system.configurationRevision = inputs.self.rev or null;

  systemd.services.nixos-upgrade = {
    serviceConfig.ExecCondition = guard;
    unitConfig = {
      OnFailure = [ "nixos-upgrade-failed.service" ];
      OnSuccess = [ "nixos-upgrade-health.service" ];
    };
  };

  # Also covers a switch that went through but left units failed:
  # switch-to-configuration exits non-zero for that.
  systemd.services.nixos-upgrade-failed = {
    description = "Report a failed NixOS upgrade to Home Assistant";
    serviceConfig.Type = "oneshot";
    script = ''
      # nixos-upgrade.service is failed itself at this point, so it is in the list
      failed=$(${failedUnits})
      ${notify} "''${failed:-nixos-upgrade.service}"
    '';
  };

  # Units that fall over shortly after a switch that looked fine.
  systemd.services.nixos-upgrade-health = {
    description = "Report units that failed after a NixOS upgrade to Home Assistant";
    serviceConfig.Type = "oneshot";
    script = ''
      if [ "$(cat ${before} 2>/dev/null)" = "$(readlink /run/current-system)" ]; then
        exit 0 # nothing new was activated
      fi
      sleep 300
      failed=$(${failedUnits})
      if [ -n "$failed" ]; then
        ${notify} "$failed"
      fi
    '';
  };
}
