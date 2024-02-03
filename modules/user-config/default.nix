{ lib, ... }:
with lib; {
  imports = [ ] ++ lib.optional (builtins.pathExists ./config.nix) ./config.nix;
  options.userConfig = {
    username = mkOption {
      type = types.str;
      description = "Your username.";
      default = "nix";
    };
  };
}
