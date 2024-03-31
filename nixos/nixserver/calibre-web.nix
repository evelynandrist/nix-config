{ config, lib, pkgs, ... }: {
  services.calibre-web = {
    enable = true;
    listen.port = 8004;
    dataDir = "../../persist/data/calibre-web/config";
    options = {
      enableBookUploading = true;
      calibreLibrary = /persist/data/calibre-web/books;
    };
  };
}
