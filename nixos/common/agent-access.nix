# What the agent (T3 Code on dellserver, nixos/dellserver/agent.nix) may do
# on this host: log in over ssh as `agent`, read the journal and unit
# status, and run exactly two commands as root:
#
#   sudo agent-test-deploy <PR number>
#     Test-deploys the head commit of a nix-config pull request, but only if
#     the PR is open, comes from the repo itself (not a fork) and carries the
#     label `test-deploy`. Only Evelyn can set that label: it needs a GitHub
#     login, which the agent never gets. The label approves the branch, not
#     one commit, so remove it when the task is done.
#     `nixos-rebuild test` does not change the boot default: a reboot, or the
#     nightly upgrade (its guard looks at the system profile, which `test`
#     leaves alone), returns the host to main.
#
#   sudo systemctl start nixos-upgrade.service
#     Returns the host to main now.
#
# Imported by packardserver, dellserver and nixserver.
{ config, pkgs, ... }:
let
  repo = "evelynandrist/nix-config";
  host = config.networking.hostName;

  testDeploy = pkgs.writeShellApplication {
    name = "agent-test-deploy";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      config.nix.package
      config.system.build.nixos-rebuild
    ];
    text = ''
      if [ $# -ne 1 ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "usage: agent-test-deploy <PR number>" >&2
        exit 2
      fi

      # unauthenticated: 60 requests an hour per address
      pr=$(curl -fsS --max-time 30 -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/${repo}/pulls/$1")

      state=$(jq -r '.state' <<<"$pr")
      head_repo=$(jq -r '.head.repo.full_name // empty' <<<"$pr")
      labelled=$(jq -r 'any(.labels[]; .name == "test-deploy")' <<<"$pr")
      sha=$(jq -r '.head.sha' <<<"$pr")

      if [ "$state" != open ]; then
        echo "PR #$1 is not open." >&2; exit 1
      fi
      if [ "$head_repo" != ${repo} ]; then
        echo "PR #$1 does not come from ${repo}." >&2; exit 1
      fi
      if [ "$labelled" != true ]; then
        echo "PR #$1 does not have the label test-deploy." >&2; exit 1
      fi
      if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "Unexpected head commit: $sha" >&2; exit 1
      fi

      echo "Test-deploying PR #$1 at $sha on ${host}."
      exec nixos-rebuild test --flake "github:${repo}/$sha#${host}"
    '';
  };
in {
  users.groups.agent = { };
  users.users.agent = {
    isNormalUser = true;
    group = "agent";
    extraGroups = [ "systemd-journal" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID4Bn41L9SvJwW6xRdnysYEwDuhd9gG/5YD1WOGyuAvU agent@dellserver"
    ];
  };

  # throwaway: marker for the first test deploy, never merge
  environment.etc."agent-test-deploy".text = "test deploy works\n";

  environment.systemPackages = [ testDeploy ];

  security.sudo.extraRules = [{
    users = [ "agent" ];
    runAs = "root";
    commands = [
      {
        command = "/run/current-system/sw/bin/agent-test-deploy *";
        options = [ "NOPASSWD" ];
      }
      {
        command = "/run/current-system/sw/bin/systemctl start nixos-upgrade.service";
        options = [ "NOPASSWD" ];
      }
    ];
  }];
}
