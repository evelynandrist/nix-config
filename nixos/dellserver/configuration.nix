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
    ./paperless.nix
    ./samba.nix
    ./paperless-single-sheets.nix
    ./agent.nix
    ./flake-update.nix
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    # Swapping to zram is cheap, so prefer it over dropping page cache.
    "vm.swappiness" = 180;
    # Readahead is pointless for RAM-backed swap.
    "vm.page-cluster" = 0;
    # Start reclaiming earlier and more gradually. The default (10) lets the machine
    # run into direct reclaim, which is what blocks processes for tens of ms at a time.
    "vm.watermark_scale_factor" = 125;
  };

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

  # Docker with access to the GPU. A container asks for the card with
  # `--device nvidia.com/gpu=all` (not `--gpus all`). Nobody is in the docker
  # group, which would be root without a password: use `sudo docker`.
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";
  virtualisation.oci-containers.backend = "docker";
  hardware.nvidia-container-toolkit.enable = true;
  # Kept across reboots, so the large GPU images are not pulled again every
  # time. Left out of the backup: images can be pulled again, and container
  # data belongs in /persist/data, not in Docker's own volumes.
  environment.persistence."/persist".directories = [ "/var/lib/docker" ];
  services.restic.backups.truenas.exclude = [ "/persist/var/lib/docker" ];

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
