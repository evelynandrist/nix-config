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
          security create-keychain -p "$PW" "$KEYCHAIN"
          security import "$p12" -k "$KEYCHAIN" -T /usr/bin/codesign
          security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
	  # without this codesign will still raise a GUI prompt even against an unlocked keychain
          security set-key-partition-list -S apple-tool:,apple: -k "$PW" "$KEYCHAIN"
          # No -t: disable the auto-relock timeout.
          security set-keychain-settings "$KEYCHAIN"
          ;;

        status)
          security show-keychain-info "$KEYCHAIN"
          ;;

        *)
          echo "usage: ios-keychain unlock|create <cert.p12>|status" >&2
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

    # macOS ships rsync 2.6.9 from 2006; `ios sync` needs a modern one on both
    # ends for the -ain dry-run output it parses.
    rsync
  ];
}
