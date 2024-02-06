{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [
    mpvpaper
    wpgtk
  ];
}
