{ config, lib, pkgs, ... }: {
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/archisteamfarm";
      persistentStoragePath = "/persist/data/archisteamfarm";
    }
  ];

  services.archisteamfarm = {
    enable = true;
    web-ui = {
      enable = true;
    };
  };
}
