{ config, lib, pkgs, ... }: {
  services.terraria = {
    enable = true;
    dataDir = "/persist/data/terraria";
    worldPath = "/persist/data/terraria/Athen.wld";
  };
}
