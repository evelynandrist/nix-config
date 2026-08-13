# Top-level nix-darwin configuration for the MacBook Pro M1 Pro.
#
# Mirrors nixos/common/configuration.nix where the option names carry over.
# See docs/macbook-integration.md, Phase 1, for the ones that do not.
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.home-manager.darwinModules.home-manager

    ./userconfig.nix
    ./homebrew.nix
    ./defaults.nix
  ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.master-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    nixPath = ["/etc/nix/path"];
    settings.experimental-features = "nix-command flakes";
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = [{ Weekday = 1; Hour = 3; Minute = 0; }];
      options = "--delete-older-than 30d";
    };
  };

  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;


  system = {
    primaryUser = config.userConfig.username;
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };

  time.timeZone = "Europe/Zurich";

  users.users.${config.userConfig.username} = {
    home = "/Users/${config.userConfig.username}";
    shell = pkgs.zsh;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = false;
  };

  # GUI apps (kitty, AeroSpace) resolve fonts by name through the system font
  # path; fonts installed into a home-manager profile are not reliably found.
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    file
    neovim
    nix-output-monitor
    wget
    git
  ];

  environment.pathsToLink = [ "/share/zsh" ];

  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs outputs; };
    users = {
      ${config.userConfig.username} = import ../../home-manager/nixbook/home.nix;
    };
  };

  system.stateVersion = 7;
}
