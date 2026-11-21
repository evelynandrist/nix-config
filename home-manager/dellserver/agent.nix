# The agent user on dellserver (nixos/dellserver/agent.nix). Not based on
# ../common/home.nix: that one signs commits with Evelyn's gpg key and logs
# gh in, neither of which the agent may have. Only the zsh setup is shared,
# so T3's terminal looks like Evelyn's.
{ pkgs, ... }:
let
  # `mac` — copy a worktree to the nixbook and build there.
  #
  # The agent logs in to the Mac as Evelyn (home-manager/nixbook/ssh.nix), so
  # the rules below are what keeps it out of her own repo folders there:
  # everything it writes is under ~/t3/<repo>/<branch>. Her folders may be
  # read (symlink large ignored video files from them), never written.
  #
  # What is copied is exactly what git lists: tracked files (submodules
  # included) and untracked files that are not ignored. The list of the last
  # sync is kept on the Mac as ~/t3/<repo>/.<branch>.files. The next sync
  # deletes only files from that list that git no longer lists, so anything
  # the Mac side made itself (build output, video symlinks) is never deleted.
  mac = pkgs.writeShellApplication {
    name = "mac";
    runtimeInputs = with pkgs; [ rsync openssh git coreutils findutils gnused ];
    text = ''
      set -euo pipefail

      HOST=nixbook
      BASE=t3
      # macOS ships an ancient rsync; use the one from Evelyn's profile
      RSYNC_REMOTE=/etc/profiles/per-user/evelyn/bin/rsync

      # Names become paths on the Mac: allow nothing that could leave ~/t3.
      check_name() {
        case "$1" in
          ""|.|..|*[!A-Za-z0-9._-]*)
            echo "mac: bad name '$1'" >&2; exit 1 ;;
        esac
      }

      # t3/<repo>/<branch> for the git worktree we are in. A slash in the
      # branch name becomes a dash, so feat/x and feat-x share one folder.
      target() {
        local common repo branch
        git rev-parse --git-dir >/dev/null 2>&1 \
          || { echo "mac: not in a git repository" >&2; exit 1; }
        common="$(git rev-parse --path-format=absolute --git-common-dir)"
        repo="$(basename "$(dirname "$common")")"
        branch="$(git symbolic-ref --short -q HEAD \
          || basename "$(git rev-parse --show-toplevel)")"
        branch="''${branch//\//-}"
        check_name "$repo"; check_name "$branch"
        printf '%s/%s/%s' "$BASE" "$repo" "$branch"
      }

      # t3/<repo>/.<branch>.files, the list of the last sync
      manifest_of() {
        printf '%s/.%s.files' "''${1%/*}" "''${1##*/}"
      }

      remote() {
        # shellcheck disable=SC2029
        ssh "$HOST" "$@"
      }

      # Runs on the Mac with the stale paths as arguments. Removes each file
      # and the folders it leaves empty.
      # shellcheck disable=SC2016
      RM_STALE='rc=0; for f; do case "$f" in /*|../*|*/../*) continue;; esac; rm -f -- "$f" || rc=1; rmdir -p -- "$(dirname -- "$f")" 2>/dev/null; done; exit $rc'

      case "''${1:-}" in
        sync)
          dir="$(target)"
          manifest="$(manifest_of "$dir")"
          root="$(git rev-parse --show-toplevel)"
          tmp="$(mktemp -d)"
          trap 'rm -rf "$tmp"' EXIT
          export LC_ALL=C

          # Files in the index that are gone from the worktree are left out:
          # rsync would fail on them.
          ( cd "$root"
            { git ls-files -cz --recurse-submodules
              git ls-files -oz --exclude-standard
            } | while IFS= read -r -d "" f; do
              if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
            done | sort -zu > "$tmp/new" )

          remote "mkdir -p ~/$dir && cat ~/$manifest 2>/dev/null || true" > "$tmp/old"

          # Stale files go first, so a file that became a folder (or the
          # other way round) does not block the copy.
          comm -z -23 "$tmp/old" "$tmp/new" > "$tmp/stale"
          if [ -s "$tmp/stale" ]; then
            remote "cd ~/$dir && xargs -0 sh -c $(printf '%q' "$RM_STALE") sh" < "$tmp/stale"
          fi

          rsync -a --from0 --files-from="$tmp/new" \
            --rsync-path="$RSYNC_REMOTE" "$root"/ "$HOST:$dir"/
          rsync --rsync-path="$RSYNC_REMOTE" "$tmp/new" "$HOST:$manifest"
          echo "$HOST:~/$dir"
          ;;
        run)
          shift
          dir="$(target)"
          [ "$#" -gt 0 ] || { echo "usage: mac run <command> [args]" >&2; exit 1; }
          # each argument reaches the Mac as one word
          remote "cd ~/$dir && $(printf '%q ' "$@")"
          ;;
        dir)
          dir="$(target)"
          echo "$HOST:~/$dir"
          ;;
        ls)
          remote "cd ~/$BASE 2>/dev/null && find . -mindepth 2 -maxdepth 2 -type d | sed 's|^\./||' | sort || true"
          ;;
        clean)
          shift
          if [ "$#" -eq 0 ]; then
            dir="$(target)"
          else
            arg="''${1%/}"
            case "$arg" in */*) ;; *) echo "usage: mac clean [repo/branch]" >&2; exit 1 ;; esac
            repo="''${arg%%/*}"; branch="''${arg#*/}"
            check_name "$repo"; check_name "$branch"
            dir="$BASE/$repo/$branch"
          fi
          manifest="$(manifest_of "$dir")"
          parent="''${dir%/*}"
          # only the rmdir may fail: other branches may still be there
          remote "rm -rf ~/$dir ~/$manifest && { rmdir ~/$parent 2>/dev/null || true; }"
          echo "removed $HOST:~/$dir"
          ;;
        *)
          cat >&2 <<'EOF'
      mac — work on the nixbook from a git worktree on dellserver

        mac sync              copy this worktree to ~/t3/<repo>/<branch>:
                              the files git tracks plus untracked ones that
                              are not ignored. Files from an earlier sync
                              that git no longer lists are deleted there;
                              nothing else on the Mac is.
        mac run <command> [args]
                              run a command in that folder, e.g.
                              mac run nix/build.sh. Arguments arrive as
                              given; for shell syntax use
                              mac run sh -c 'a && b'
        mac dir               print that folder
        mac ls                list all agent folders on the Mac
        mac clean [repo/branch]
                              remove a folder (default: this worktree's)

      Only ~/t3 on the Mac is the agent's. Evelyn's own repo folders there
      may be read (e.g. symlink a large ignored video file into ~/t3), never
      written to.
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

  home.packages = [ mac ];

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
