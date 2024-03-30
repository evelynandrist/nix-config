{ config, lib, pkgs, ... }: {
  services.vaultwarden = {
    enable = true;
    backupDir = "/persist/data/vaultwarden";
    config = {
      DOMAIN = "https://vault.qwt.ch";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8002;
      ROCKET_LOG = "critical";
    };
  };
}
