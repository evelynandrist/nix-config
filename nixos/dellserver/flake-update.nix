# Weekly flake.lock bump, Sunday 20:00.
#
# Runs as `agent` (agent.nix), whose ssh key can push branches. It clones
# main into a temporary folder, runs `nix flake update`, builds every NixOS
# host and evaluates the darwin host against the new lock, and force-pushes
# the result as one commit to the branch auto/flake-update. The commit
# message lists the updated inputs and says whether everything built.
#
# It then starts a T3 thread (`t3 thread start`, in a worktree at that
# commit) and the agent takes over: it reports what in the bump matters,
# with the link that opens the pull request, and fixes mechanical breakage
# on the branch when a host does not build. The thread's push notification
# is what announces the bump. The bump itself needs no Claude: a week
# without T3 still gets its branch.
#
# It never touches main: main only changes through a pull request. The bump
# lands when Evelyn opens a PR for the branch and merges it. The hosts then
# pick it up through system.autoUpgrade (../common/auto-upgrade.nix). An
# open PR from an earlier week is updated by the push, and a fix the agent
# made on it that was not merged is gone and made again.
#
# This used to be a GitHub Actions workflow. Actions is switched off for
# the repo and must stay off: a workflow pushed on any branch can give its
# own token write access, label PRs and merge them to main, which would let
# the agent past both the test-deploy label and the pull-request rule.
#
# A host that does not build is the agent's job and does not fail the unit.
# The unit fails when the bump, the push or the thread start fails (T3 not
# running, for one), and Home Assistant is told, through the webhook of
# ../common/auto-upgrade.nix. A week without updates is silent.
#
# The thread runs unattended and without approvals, so its message is made
# of host names and input names only, never of build output.
#
# The other hosts' systems are built here, so they take up space in
# dellserver's store until the next garbage collection. Each week's thread
# leaves a worktree in /home/agent/worktrees/nix-config.
#
# Run now:  sudo systemctl start flake-update.service
# Log:      journalctl -u flake-update
{ config, pkgs, ... }:
let
  repo = "evelynandrist/nix-config";
  branch = "auto/flake-update";
  hosts = [ "nixpad" "nixserver" "packardserver" "dellserver" ];
  # T3's project, where the thread starts
  project = "${config.users.users.agent.home}/repos/nix-config";
in {
  systemd.services.flake-update = {
    description = "Update flake.lock, build all hosts, push ${branch}, start a thread";
    after = [ "network-online.target" "agent-ssh-key.service" "t3code.service" ];
    wants = [ "network-online.target" ];
    path = [
      config.nix.package pkgs.git pkgs.openssh pkgs.gnugrep
      # t3, with the Connect wrapper of agent.nix
      "/etc/profiles/per-user/agent"
    ];
    environment.HOME = config.users.users.agent.home;
    unitConfig.OnFailure = [ "flake-update-failed.service" ];
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

      if [ -z "$failed" ]; then
        result="All hosts build and nixbook evaluates."
        title="Flake update: all hosts build"
      else
        result="DOES NOT BUILD:$failed"
        title="Flake update: does not build:$failed"
      fi
      # the list of updated inputs
      inputs=$(grep -v '^warning:' ../update.log || true)

      printf '%s\n\n%s\n\n%s\n' "chore: update flake.lock" "$result" "$inputs" > ../message
      git commit --quiet -F ../message flake.lock
      git push --force origin "HEAD:refs/heads/${branch}"

      # the thread's worktree starts from origin/${branch} of T3's clone
      git -C ${project} fetch --quiet origin

      # The project has no default model, so both flags are needed.
      t3 thread start --provider claudeAgent --model claude-fable-5-2 \
        --worktree "origin/${branch}" --title "$title" ${project} - <<EOF
      The weekly flake.lock bump is pushed to the branch ${branch}, and this
      worktree is at that commit. nixos/dellserver/flake-update.nix made it
      and explains the rest. Nobody is watching this turn.

      $result

      $inputs

      Do this, then report to Evelyn, short:

      1. If a host does not build, fix mechanical breakage only: a renamed or
         removed option, a moved or renamed package. Make it a commit of its
         own on top of the bump and build again. What changes behaviour or
         touches data (a major version of a service, a migration, a changed
         default) is not yours to decide: report it and leave it to Evelyn.
      2. Say what in the bump matters for the hosts. Compare each host's
         system on main and on this commit with "nix store diff-closures" and
         name the major version jumps of the services the hosts run. Leave
         out the rest.
      3. Push a fix with: git push origin HEAD:${branch}
      4. End with the link that opens the pull request:
         https://github.com/${repo}/compare/main...${branch}?quick_pull=1

      A test deploy before the merge is there when Evelyn asks for it: she
      sets the label test-deploy on the pull request and says so here. Then
      use the skill deploy, with dellserver last: its test deploy restarts
      T3, and this turn then waits for Resume.

      Next Sunday's bump force-pushes the branch. A fix that is not merged
      by then is made again.
      EOF
    '';
  };

  # Root, for the webhook secret, which the agent must not read.
  systemd.services.flake-update-failed = {
    description = "Report a failed flake update to Home Assistant";
    serviceConfig.Type = "oneshot";
    script = ''
      payload=$(${pkgs.jq}/bin/jq -cn --arg host ${config.networking.hostName} \
        '{host: $host, message: "flake-update.service"}')
      ${pkgs.curl}/bin/curl -fsS --retry 5 --retry-delay 30 --retry-all-errors \
        -X POST -H 'Content-Type: application/json' -d "$payload" \
        "https://home.qwt.ch/api/webhook/$(cat ${config.sops.secrets."upgrade/ha_webhook_id".path})"
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
