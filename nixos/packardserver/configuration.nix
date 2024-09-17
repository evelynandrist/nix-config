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

    ./hardware-configuration.nix

    ./nginx.nix
    ./media-stack.nix

    ./userconfig.nix
  ];
  
  # # backup can be triggered with sudo systemctl start restic-backups-pcloud.service
  # services.restic.backups.pcloud = {
  #   repository = "rclone:pcloud:/nixpad-backups";
  #   initialize = true;
  #   rcloneConfigFile = "${config.sops.templates."rclone.conf".path}";
  #   passwordFile = "${config.sops.secrets."pcloud/password".path}";
  #   paths = [ "/home/${config.userConfig.username}/packardserver_backup" ];
  # };

  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };
    efi.canTouchEfiVariables = true;
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users = {
      # Import your home-manager configuration
      ${config.userConfig.username} = import ../../home-manager/packardserver/home.nix;
    };
  };

  networking = {
    hostName = "packardserver";
  };

  users.users.${config.userConfig.username}.extraGroups = [ "network" "rfkill" "power" "wheel" "docker" ];

  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";
  virtualisation.oci-containers.backend = "docker";

  networking.firewall = {
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ ];
  };
}
