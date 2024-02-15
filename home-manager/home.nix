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
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    inputs.nix-colors.homeManagerModules.default

    ../modules/user-config
    ../modules/video-paper

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ./hyprland.nix
    ./waybar.nix
    ./kitty.nix
    ./zsh.nix
    ./wofi.nix
    ./firefox.nix
    ./doom.nix
    ./latex.nix
  ];

  #colorScheme = inputs.nix-colors.colorSchemes.catppuccin-mocha;
  /*colorScheme = nix-colors-lib.colorSchemeFromPicture {
    path = ./Chill-Beach.jpg;
    variant = "dark";
  };*/

  moewalls = {
    url = "https://moewalls.com/landscape/forest-pond-rainy-day-live-wallpaper/";
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
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # TODO: Set your username
  home = {
    username = "${config.userConfig.username}";
    homeDirectory = "/home/${config.userConfig.username}";
  };

  home.pointerCursor = {
    name = "Catppuccin-Mocha-Dark-Cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 32;
  };

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userEmail = "kevin1bam@web.de";
    userName = "Kevin Bam";
    signing = {
      key = "5A71E723055533FE";
      signByDefault = true;
    };
  };

  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "tty";
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.11";
}
