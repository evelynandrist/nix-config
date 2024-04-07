{ config, lib, pkgs, ... }: {
  services.calibre-web = {
    enable = true;
    package = pkgs.master.calibre-web;
    listen.port = 8004;
    options = {
      enableBookUploading = true;
    };
    dataDir = "../../persist/data/calibre-web/config";
  };
}
