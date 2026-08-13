{ config, ... }: {
  imports = [ ../../modules/user-config/default.nix ];

  config.userConfig = {
    username = "evelyn";
    secretsDir = "/Users/${config.userConfig.username}/.secrets";
  };
}
