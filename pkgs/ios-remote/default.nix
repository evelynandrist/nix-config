# `ios` — drive an Xcode build on the MacBook from nixpad.
#
# The iOS project is edited here and built there. The tree on the Mac is a
# derived build artifact, never an editing target: `ios sync` runs
# `rsync --delete`, so anything edited on the Mac is destroyed on the next
# build. Two things guard that:
#
#   * `ios shell` exists for inspection and tooling, and is documented as such.
#   * `ios sync` refuses to run when it would clobber a remote file that is
#     newer than its local counterpart, unless --force is given.
{ lib
, writeShellApplication
, rsync
, openssh
, watchexec
, coreutils
, findutils
, gnugrep
, gnused
}:

writeShellApplication {
  name = "ios";

  runtimeInputs = [ rsync openssh watchexec coreutils findutils gnugrep gnused ];

  text = ''
    set -euo pipefail

    # --- configuration -----------------------------------------------------
    # Overridable per project by a .ios-remote file in the project root, which
    # is sourced as shell. Recognised variables: IOS_SCHEME, IOS_PROJECT_FILE,
    # IOS_SIM_DESTINATION, IOS_REMOTE_HOST, IOS_REMOTE_DIR, IOS_BUNDLE_ID.
    IOS_REMOTE_HOST="''${IOS_REMOTE_HOST:-nixbook}"

    find_root() {
      local dir="$PWD"
      while [ "$dir" != "/" ]; do
        if [ -e "$dir/.ios-remote" ] || [ -e "$dir/Package.swift" ] \
          || find "$dir" -maxdepth 1 \
               \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) \
               -print -quit | grep -q .; then
          printf '%s' "$dir"
          return 0
        fi
        dir="$(dirname "$dir")"
      done
      echo "ios: no Xcode project found in $PWD or any parent" >&2
      return 1
    }

    # Resolved lazily so `ios` with no arguments still prints usage outside a
    # project directory.
    init_project() {
      ROOT="$(find_root)"
      PROJECT_NAME="$(basename "$ROOT")"
      # shellcheck source=/dev/null
      [ -e "$ROOT/.ios-remote" ] && . "$ROOT/.ios-remote"

      IOS_REMOTE_DIR="''${IOS_REMOTE_DIR:-build/$PROJECT_NAME}"
      IOS_SIM_DESTINATION="''${IOS_SIM_DESTINATION:-platform=iOS Simulator,name=iPhone 16}"
    }

    # Build outputs, dependency checkouts and the git dir never cross the wire.
    # Note .git being excluded is also why an edit made on the Mac cannot be
    # recovered there — hence the guard in `sync`.
    EXCLUDES=(
      --exclude '.git/'
      --exclude 'DerivedData/'
      --exclude '.build/'
      --exclude 'Pods/'
      --exclude '.swiftpm/'
      --exclude '*.xcuserdatad/'
    )

    remote() {
      # Client-side expansion is deliberate: the commands are built here from
      # local configuration and run as one string on the Mac.
      # shellcheck disable=SC2029
      ssh "$IOS_REMOTE_HOST" "$@"
    }

    xcodebuild_args() {
      local -a args=()
      if [ -n "''${IOS_PROJECT_FILE:-}" ]; then
        case "$IOS_PROJECT_FILE" in
          *.xcworkspace) args+=(-workspace "$IOS_PROJECT_FILE") ;;
          *)             args+=(-project "$IOS_PROJECT_FILE") ;;
        esac
      fi
      [ -n "''${IOS_SCHEME:-}" ] && args+=(-scheme "$IOS_SCHEME")

      if [ "''${#args[@]}" -gt 0 ]; then
        printf '%q ' "''${args[@]}"
      fi
    }

    # --- sync --------------------------------------------------------------
    # The dry run is the whole point: rsync --delete is silent about what it
    # destroys, and with .git excluded there is no way to see it afterwards.
    do_sync() {
      local force=0
      [ "''${1:-}" = "--force" ] && force=1

      remote "mkdir -p ~/$IOS_REMOTE_DIR"

      if [ "$force" -eq 0 ]; then
        local at_risk
        at_risk="$(rsync -ain --delete "''${EXCLUDES[@]}" \
          "$ROOT"/ "$IOS_REMOTE_HOST:$IOS_REMOTE_DIR"/ \
          | grep -E '^(\*deleting|[<>]f)' || true)"

        if [ -n "$at_risk" ]; then
          local newer
          newer="$(printf '%s\n' "$at_risk" \
            | sed -E 's/^[^ ]+ //' \
            | while IFS= read -r f; do
                [ -z "$f" ] && continue
                local_mtime=0
                [ -e "$ROOT/$f" ] && local_mtime="$(stat -c %Y "$ROOT/$f")"
                remote_mtime="$(remote "stat -f %m ~/$IOS_REMOTE_DIR/$f 2>/dev/null || echo 0")"
                if [ "$remote_mtime" -gt "$local_mtime" ]; then printf '%s\n' "$f"; fi
              done)"

          if [ -n "$newer" ]; then
            echo "ios: refusing to sync — these files are newer on $IOS_REMOTE_HOST" >&2
            echo "     than locally, and would be overwritten or deleted:" >&2
            printf '       %s\n' "$newer" >&2
            echo "     The Mac tree is a build artifact; edit on nixpad." >&2
            echo "     Re-run with 'ios sync --force' if you really mean it." >&2
            return 1
          fi
        fi
      fi

      rsync -a --delete "''${EXCLUDES[@]}" \
        "$ROOT"/ "$IOS_REMOTE_HOST:$IOS_REMOTE_DIR"/
    }

    # --- build -------------------------------------------------------------
    do_build() {
      local raw=0
      if [ "''${1:-}" = "--raw" ]; then raw=1; shift; fi

      do_sync >/dev/null

      local cmd
      cmd="cd ~/$IOS_REMOTE_DIR && xcodebuild $(xcodebuild_args) -destination '$IOS_SIM_DESTINATION' $* build"

      if [ "$raw" -eq 1 ]; then
        # Untouched clang-style diagnostics, for vim's errorformat. Piping
        # through xcbeautify here would silently produce an empty quickfix list.
        remote "$cmd"
      else
        remote "$cmd | xcbeautify"
      fi
    }

    do_device_build() {
      do_sync >/dev/null
      # Unlocking happens Mac-side so the keychain password never leaves it.
      remote "ios-keychain unlock && cd ~/$IOS_REMOTE_DIR && \
        xcodebuild $(xcodebuild_args) -destination 'generic/platform=iOS' \
        -allowProvisioningUpdates build | xcbeautify"
    }

    usage() {
      cat >&2 <<'EOF'
    ios — remote iOS build loop against the MacBook

      ios sync [--force]   push the tree (rsync --delete, guarded)
      ios build [--raw]    sync, then xcodebuild; --raw skips xcbeautify so
                           vim's :make can parse the diagnostics
      ios sim              build and run on a booted simulator
      ios device           build and install on a tethered device
      ios log              stream the booted simulator's log
      ios watch            rebuild on every local change
      ios shell            ssh to the Mac — inspection only, NOT for editing:
                           the tree there is overwritten by the next sync
    EOF
      exit 1
    }

    case "''${1:-}" in
      sync)   shift; init_project; do_sync "$@" ;;
      build)  shift; init_project; do_build "$@" ;;
      sim)
        shift
        init_project
        do_build "$@"
        remote "cd ~/$IOS_REMOTE_DIR && \
          xcrun simctl boot '$(echo "$IOS_SIM_DESTINATION" | sed -E 's/.*name=//')' 2>/dev/null || true"
        app="$(remote "cd ~/$IOS_REMOTE_DIR && xcodebuild $(xcodebuild_args) \
          -destination '$IOS_SIM_DESTINATION' -showBuildSettings 2>/dev/null \
          | awk -F' = ' '/ BUILT_PRODUCTS_DIR / {d=\$2} / FULL_PRODUCT_NAME / {n=\$2} END {print d \"/\" n}'")"
        remote "xcrun simctl install booted '$app'"
        [ -n "''${IOS_BUNDLE_ID:-}" ] && remote "xcrun simctl launch booted '$IOS_BUNDLE_ID'"
        ;;
      device) shift; init_project; do_device_build "$@"; remote "ios-deploy --bundle ~/$IOS_REMOTE_DIR/build/Build/Products/*-iphoneos/*.app" ;;
      log)    shift; init_project; remote "xcrun simctl spawn booted log stream --style compact ''${*:-}" ;;
      watch)  shift; init_project; watchexec --project-origin "$ROOT" -w "$ROOT" -e swift,m,mm,h,plist,storyboard,xib -- ios build "$@" ;;
      shell)  shift; init_project; ssh -t "$IOS_REMOTE_HOST" "cd ~/$IOS_REMOTE_DIR && exec \$SHELL -l" ;;
      *)      usage ;;
    esac
  '';

  meta = {
    description = "Drive Xcode builds on a remote Mac from nixpad";
    mainProgram = "ios";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
