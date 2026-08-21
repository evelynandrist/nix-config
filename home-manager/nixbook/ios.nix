{ config, lib, pkgs, ... }:
let
  passwordFile = "${config.userConfig.secretsDir}/nixbook/build_keychain_password";

  # Code signing over ssh needs an unlocked keychain, which usually requires a GUI prompt.
  # Create a build keychain and store its password in sops (we don't want the macOS account
  # password in sops).
  ios-keychain = pkgs.writeShellApplication {
    name = "ios-keychain";
    text = ''
      set -euo pipefail

      KEYCHAIN="''${IOS_KEYCHAIN:-build.keychain}"
      PW_FILE="${passwordFile}"

      pw() {
        if [ ! -r "$PW_FILE" ]; then
          echo "ios-keychain: cannot read $PW_FILE" >&2
          echo "  (sops secret not materialised — check nix-config README)" >&2
          exit 1
        fi
        cat "$PW_FILE"
      }

      case "''${1:-}" in
        unlock)
          security unlock-keychain -p "$(pw)" "$KEYCHAIN"
          ;;

        create)
          # One-time setup. Takes the exported .p12 as its argument.
          p12="''${2:?usage: ios-keychain create <cert.p12>}"
          PW="$(pw)"

          # A failed import still leaves the keychain created, so the obvious
          # retry dies with "A keychain with the same name already exists" and
          # the half-built keychain is useless either way. Say so, rather than
          # letting security's message imply the setup already succeeded.
          if security show-keychain-info "$KEYCHAIN" >/dev/null 2>&1; then
            echo "ios-keychain: $KEYCHAIN already exists." >&2
            echo "  If a previous 'create' failed part way, discard it first:" >&2
            echo "    ios-keychain delete" >&2
            exit 1
          fi

          # Read the .p12 export passphrase here rather than letting `security`
          # ask for it. Without -P it opens a GUI dialog, which over ssh fails as
          # "SecKeychainItemImport: User interaction is not allowed" — the very
          # situation this keychain exists to avoid. Terminal input is fine; it
          # is the Security framework's own prompt that needs a window server.
          # An empty answer is valid and passes -P "" — an unprotected .p12
          # imports fine, it just must not be left to prompt.
          printf 'passphrase for %s: ' "$(basename "$p12")" >&2
          read -rs P12_PW
          printf '\n' >&2

          security create-keychain -p "$PW" "$KEYCHAIN"
          # create-keychain leaves the keychain unlocked, but be explicit: an
          # import into a locked keychain fails the same opaque way.
          security unlock-keychain -p "$PW" "$KEYCHAIN"
          security import "$p12" -k "$KEYCHAIN" -P "$P12_PW" \
            -T /usr/bin/codesign -T /usr/bin/security
          security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
	  # without this codesign will still raise a GUI prompt even against an unlocked keychain
          security set-key-partition-list -S apple-tool:,apple: -k "$PW" "$KEYCHAIN"
          # No -t: disable the auto-relock timeout.
          security set-keychain-settings "$KEYCHAIN"
          ;;

        delete)
          # Only ever removes the dedicated build keychain, never login.keychain:
          # KEYCHAIN defaults to build.keychain and the signing identity is
          # re-importable from the .p12, so nothing unrecoverable is lost.
          security delete-keychain "$KEYCHAIN"
          echo "ios-keychain: removed $KEYCHAIN" >&2
          ;;

        status)
          security show-keychain-info "$KEYCHAIN"
          ;;

        *)
          echo "usage: ios-keychain unlock|create <cert.p12>|delete|status" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  home.packages = with pkgs; [
    ios-keychain

    xcbeautify
    ios-deploy
    libimobiledevice
    xcodes

    # creates the buildServer.json needed for the LSP on darwin
    xcode-build-server

    # macOS ships rsync 2.6.9 from 2006; `ios sync` needs a modern one on both
    # ends for the -ain dry-run output it parses.
    rsync
  ];
}
