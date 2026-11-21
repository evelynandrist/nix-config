# Weekly flake.lock bump, Sunday 20:00.
#
# Runs as `agent` (agent.nix), whose ssh key can push branches. It clones
# main into a temporary folder, runs `nix flake update`, builds every NixOS
# host and evaluates the darwin host against the new lock, and force-pushes
# the result as one commit to the branch auto/flake-update. The commit
# message lists the updated inputs and says whether everything built.
#
# It never touches main: main only changes through a pull request. The bump
# lands when Evelyn opens a PR for the branch and merges it:
#   https://github.com/evelynandrist/nix-config/pull/new/auto/flake-update
# The hosts then pick it up through system.autoUpgrade
# (../common/auto-upgrade.nix). An open PR from an earlier week is updated
# by the push.
#
# This used to be a GitHub Actions workflow. Actions is switched off for
# the repo and must stay off: a workflow pushed on any branch can give its
# own token write access, label PRs and merge them to main, which would let
# the agent past both the test-deploy label and the pull-request rule.
#
# When a host does not build, the branch is pushed anyway (to fix it there)
# and the unit ends as failed. Nothing announces a successful bump.
#
# The other hosts' systems are built here, so they take up space in
# dellserver's store until the next garbage collection.
#
# Run now:  sudo systemctl start flake-update.service
# Log:      journalctl -u flake-update
{ config, pkgs, ... }:
let
  repo = "evelynandrist/nix-config";
  branch = "auto/flake-update";
  hosts = [ "nixpad" "nixserver" "packardserver" "dellserver" ];
in {
  systemd.services.flake-update = {
    description = "Update flake.lock, build all hosts, push ${branch}";
    after = [ "network-online.target" "agent-ssh-key.service" ];
    wants = [ "network-online.target" ];
    path = [ config.nix.package pkgs.git pkgs.openssh pkgs.gnugrep ];
    environment.HOME = config.users.users.agent.home;
    serviceConfig = {
      Type = "oneshot";
      User = "agent";
      Group = "agent";
      # removed again when the run ends
      RuntimeDirectory = "flake-update";
      WorkingDirectory = "%t/flake-update";
      # hours of building should not get in the way of the services
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -euo pipefail

      git clone --quiet --depth 1 git@github.com:${repo} repo
      cd repo

      nix flake update 2> >(tee ../update.log >&2)
      if git diff --quiet flake.lock; then
        echo "flake.lock is up to date"
        exit 0
      fi

      failed=""
      for host in ${toString hosts}; do
        nix build --no-link --print-build-logs \
          ".#nixosConfigurations.$host.config.system.build.toplevel" || failed+=" $host"
      done
      # No macOS builder: evaluating catches renamed and removed options,
      # which is most of what breaks.
      nix eval --raw .#darwinConfigurations.nixbook.config.system.build.toplevel.drvPath \
        > /dev/null || failed+=" nixbook"

      {
        echo "chore: update flake.lock"
        echo
        if [ -z "$failed" ]; then
          echo "All hosts build and nixbook evaluates."
        else
          echo "DOES NOT BUILD:$failed"
        fi
        echo
        # the list of updated inputs
        grep -v '^warning:' ../update.log || true
      } > ../message

      git commit --quiet -F ../message flake.lock
      git push --force origin "HEAD:refs/heads/${branch}"

      [ -z "$failed" ]
    '';
  };

  systemd.timers.flake-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # done long before the 04:00 upgrades
      OnCalendar = "Sun 20:00";
      Persistent = true;
    };
  };
}
