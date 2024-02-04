{ lib, ... }:
with lib; {
  imports = [ ./config.nix ];
  options.userConfig = {
    username = mkOption {
      type = types.str;
      description = "Your username.";
      default = "nix";
    };
  };
}
