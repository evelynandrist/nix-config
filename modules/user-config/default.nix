{ lib, ... }:
with lib; {
  options.userConfig = {
    username = mkOption {
      type = types.str;
      description = "Your username.";
      default = "nix";
    };
  };
}
