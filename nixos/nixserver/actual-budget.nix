{ config, lib, pkgs, ... }: {
  services.actual = {
    enable = true;
    settings = {
      port = 31012;
      dataDir = "/persist/data/actual-budget";
    };
  };
}
