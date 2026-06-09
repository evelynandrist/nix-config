{ config, lib, pkgs, inputs, ... }: {
  # required for secfix compliance
  services.clamav = {
    daemon.enable = true;
    updater.enable = true;
  };
}
