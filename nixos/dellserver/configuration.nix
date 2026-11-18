{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../common/configuration.nix
    ../common/lan-hosts.nix
    ../common/truenas-backup.nix
    ../common/hardening.nix

    ./hardware-configuration.nix

    ./userconfig.nix
  ];

  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };
    efi.canTouchEfiVariables = true;
  };

  # stock kernel instead of zen (set in the common config): the nvidia
  # module is built and cached for it
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # A laptop used as a server: it runs with the lid closed, and the screen
  # goes dark after a minute when someone does open it.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  boot.kernelParams = [ "consoleblank=60" ];

  # RTX 3060, used without a display. There is no X server; this option is
  # still what turns the driver on.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia.open = true;

  # All state lives in /persist (impermanence).
  services.restic.backups.truenas.paths = [ "/persist" ];

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users = {
      # Import your home-manager configuration
      ${config.userConfig.username} = import ../../home-manager/dellserver/home.nix;
    };
  };

  networking = {
    hostName = "dellserver";
  };

  users.users.${config.userConfig.username}.extraGroups = [ "network" "rfkill" "power" "wheel" ];

  # allow deploying from other machines (nh os switch --target-host), wheel can sudo anyway
  nix.settings.trusted-users = [ "root" "@wheel" ];

  networking.firewall = {
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];
  };
}
