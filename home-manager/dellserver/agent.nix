# The agent user on dellserver (nixos/dellserver/agent.nix). Not based on
# ../common/home.nix: that one signs commits with Evelyn's gpg key and logs
# gh in, neither of which the agent may have. Only the zsh setup is shared,
# so T3's terminal looks like Evelyn's.
{ pkgs, ... }:
let
  # `mac` — build on the nixbook from a git worktree on dellserver.
  #
  # The agent logs in to the Mac as Evelyn (home-manager/nixbook/ssh.nix), so
  # the rules below are what keeps it out of her own repo folders there:
  # everything it writes is under ~/t3/<repo>/<branch>. Her folders may be
  # read (symlink videos, copy the extracted SDK from them), never written.
  #
  # Code travels by git, not rsync: ~/t3/<repo>/<branch> is a real repo that
  # the agent pushes to (updateInstead updates its files) and fetches results
  # and tags back from. Scripts there see the real commit, as reframe needs.
  # The Mac cannot reach GitHub; dellserver does that. No LFS: LFS files stay
  # pointer files on the Mac.
  mac = pkgs.writeShellApplication {
    name = "mac";
    runtimeInputs = with pkgs; [ openssh git coreutils ];
    text = ''
      set -euo pipefail

      HOST=nixbook
      BASE=t3

      # Names become paths on the Mac: allow nothing that could leave ~/t3.
      check_name() {
        case "$1" in
          ""|.|..|*[!A-Za-z0-9._-]*)
            echo "mac: bad name '$1'" >&2; exit 1 ;;
        esac
      }

      # Sets BRANCH and DIR=t3/<repo>/<branch> for the worktree we are in.
      # A slash in the branch name becomes a dash in DIR, so feat/x and feat-x
      # share one folder; the HEAD check in sync catches that.
      resolve() {
        git rev-parse --git-dir >/dev/null 2>&1 \
          || { echo "mac: not in a git repository" >&2; exit 1; }
        local common repo name
        common="$(git rev-parse --path-format=absolute --git-common-dir)"
        repo="$(basename "$(dirname "$common")")"
        BRANCH="$(git symbolic-ref --short -q HEAD \
          || basename "$(git rev-parse --show-toplevel)")"
        name="''${BRANCH//\//-}"
        check_name "$repo"; check_name "$name"
        DIR="$BASE/$repo/$name"
      }

      remote() {
        # shellcheck disable=SC2029
        ssh "$HOST" "$@"
      }

      case "''${1:-}" in
        sync)
          shift
          force=""
          [ "''${1:-}" = "-f" ] && force="+"
          resolve
          b="$(printf '%q' "$BRANCH")"
          # Every time, so an older folder gets the settings too. Signing is
          # off here only: Evelyn's key needs a YubiKey touch.
          remote "mkdir -p ~/$DIR && cd ~/$DIR \
            && { [ -d .git ] || git init -q -b $b; } \
            && git config receive.denyCurrentBranch updateInstead \
            && git config commit.gpgsign false \
            && git config tag.gpgsign false"
          git push -q --no-verify "$HOST:$DIR" "''${force}HEAD:refs/heads/$BRANCH"
          here="$(git rev-parse HEAD)"
          there="$(remote "git -C ~/$DIR rev-parse HEAD")"
          if [ "$here" != "$there" ]; then
            echo "mac: $HOST:~/$DIR is at $there, not $here." >&2
            echo "     Another branch with the same folder name? mac clean, then sync." >&2
            exit 1
          fi
          echo "$HOST:~/$DIR at $(git rev-parse --short HEAD)"
          ;;
        fetch)
          resolve
          git pull --ff-only --tags "$HOST:$DIR" "$BRANCH"
          ;;
        run)
          shift
          resolve
          [ "$#" -gt 0 ] || { echo "usage: mac run <command> [args]" >&2; exit 1; }
          # each argument reaches the Mac as one word
          cmd="$(printf '%q ' "$@")"
          remote "cd ~/$DIR && if [ -e flake.nix ]; then exec nix develop -c $cmd; else exec $cmd; fi"
          ;;
        ls)
          remote "cd ~/$BASE 2>/dev/null && find . -mindepth 2 -maxdepth 2 -type d | sed 's|^\./||' | sort || true"
          ;;
        clean)
          shift
          if [ "$#" -eq 0 ]; then
            resolve
          else
            arg="''${1%/}"
            case "$arg" in */*) ;; *) echo "usage: mac clean [repo/branch]" >&2; exit 1 ;; esac
            repo="''${arg%%/*}"; name="''${arg#*/}"
            check_name "$repo"; check_name "$name"
            DIR="$BASE/$repo/$name"
          fi
          # only the rmdir may fail: other branches may still be there
          remote "rm -rf ~/$DIR && { rmdir ~/''${DIR%/*} 2>/dev/null || true; }"
          echo "removed $HOST:~/$DIR"
          ;;
        *)
          cat >&2 <<'EOF'
      mac — build on the nixbook from a git worktree on dellserver

        mac sync [-f]         push this branch to ~/t3/<repo>/<branch> on the
                              Mac, a repo whose files follow the push. Only
                              commits travel: commit first. -f after an amend
                              or rebase.
        mac fetch             bring commits and tags made there back here
        mac run <command> [args]
                              run a command there, in the dev shell when the
                              repo has a flake.nix: mac run build. Arguments
                              arrive as given; for shell syntax use
                              mac run sh -c 'a && b'
        mac ls                list all agent folders on the Mac
        mac clean [repo/branch]
                              remove a folder (default: this branch's)

      A tracked file changed on the Mac (pod install, Xcode) blocks the next
      sync and reframe --run: mac run git checkout -- .

      LFS files arrive as pointers. docking-station-ios-app: copy the
      extracted SDK from Evelyn's checkout, then bootstrap skips the zip:
        mac run sh -c '/bin/cp -c -R ~/repos/docking-station-ios-app/insta360-camera-x4-ios-sdk/iOS_v1.10.4 insta360-camera-x4-ios-sdk/'

      reframe: pass --no-open, reach videos through a symlink inside the
      folder (results land beside the input), commit the caches there, then
      mac fetch.

      Only ~/t3 on the Mac is the agent's. Evelyn's own repo folders there
      may be read, never written to.
      EOF
          exit 1
          ;;
      esac
    '';
  };
in {
  imports = [ ../common/zsh.nix ];

  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "26.11";

  # jq: reading GitHub API replies (.claude/skills/deploy)
  home.packages = [ mac pkgs.jq ];

  # Read by every Claude session of this user, in every repo. Only what a
  # session cannot see for itself and would otherwise learn by failing;
  # repo rules belong in that repo's CLAUDE.md.
  home.file.".claude/CLAUDE.md".text = ''
    # The agent on dellserver

    - No GitHub or Bitbucket login: you can push branches, but not open, label
      or merge pull requests. Give Evelyn the link instead:
      https://github.com/<owner>/<repo>/compare/<base>...<branch>?quick_pull=1
    - No sudo password. If something needs root or a secret, give Evelyn the
      exact command.
    - iOS and macOS builds run on the Mac: `mac` prints the help. Only `~/t3`
      there is yours.
  '';

  programs.git = {
    enable = true;
    settings.user = {
      email = "evelyn@andrist.dev";
      name = "Evelyn Andrist";
    };
    # the agent has no signing key; main is protected by requiring a pull
    # request, not by signatures
    signing.signByDefault = false;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings.nixbook = {
      HostName = "nixbook.internal.qwt.ch";
      User = "evelyn";
      # one login for sync and the build that follows
      ControlMaster = "auto";
      ControlPath = "~/.ssh/cm-%r@%h:%p";
      ControlPersist = "10m";
      # keep a build alive across a short network blip, as on nixpad
      ServerAliveInterval = 30;
      ServerAliveCountMax = 6;
    };
  };
}
