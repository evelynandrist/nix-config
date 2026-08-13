{ lib, ... }:
with lib; {
  options.userConfig = {
    username = mkOption {
      type = types.str;
      description = "Your username.";
      default = "nix";
    };

    secretsDir = mkOption {
      type = types.str;
      description = ''
        Directory sops-nix materialises secrets into on this host.

        NixOS hosts run sops as a system module, which uses /run/secrets. The
        MacBook runs it as a home-manager module, where the default lives under
        DARWIN_USER_TEMP_DIR; darwin/macbook pins an explicit path instead so
        consumers (email.nix, ios-remote) have something stable to read.
      '';
      default = "/run/secrets";
    };
  };
}
