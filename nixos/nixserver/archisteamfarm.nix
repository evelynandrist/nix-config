{ config, lib, pkgs, ... }: {
  sops.secrets = {
    "archisteamfarm/ipc_password" = {
      owner = "archisteamfarm";
      group = "archisteamfarm";
    };
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/archisteamfarm";
      persistentStoragePath = "/persist/data/archisteamfarm";
    }
  ];

  services.archisteamfarm = {
    enable = true;
    ipcPasswordFile = config.sops.secrets."archisteamfarm/ipc_password".path;
    web-ui = {
      enable = true;
    };
  };
}
