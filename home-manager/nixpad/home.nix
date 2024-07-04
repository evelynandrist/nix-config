# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: let
  nix-colors-lib = inputs.nix-colors.lib.contrib { inherit pkgs; };
in {
  imports = [
    ../common/home.nix

    inputs.nix-colors.homeManagerModules.default

    ../../modules/video-paper

    ./hyprland.nix
    ./waybar.nix
    ./kitty.nix
    ./zsh.nix
    ./wofi.nix
    ./firefox.nix
    ./latex.nix

    ../../nixos/nixpad/userconfig.nix
  ];

  moewalls = {
    url = "https://moewalls.com/landscape/japanese-traditional-house-spring-season-live-wallpaper/";
    width = 1920;
    height = 1200;
  };

  gtk = {
    enable = true;
    theme = {
      name = "${config.colorScheme.slug}";
      package = nix-colors-lib.gtkThemeFromScheme { scheme = config.colorScheme; };
    };
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    (pkgs.nerdfonts.override { fonts = [ "FiraCode" "FiraMono" "JetBrainsMono" ]; })
    nil
    nodejs
    jq
    unzip
    xdg-utils
  ];

  home.pointerCursor = {
    name = "Catppuccin-Mocha-Dark-Cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 32;
  };
}
