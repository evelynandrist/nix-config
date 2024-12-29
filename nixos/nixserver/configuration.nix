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

    ./fakeroute.nix
    ./terraria.nix
    ./nginx.nix
    ./searx.nix
    ./vaultwarden.nix
    ./umami.nix
    ./calibre-web.nix
    # ./archisteamfarm.nix
    ./mailserver.nix
    ./immich.nix
    # ./mediawiki-legends.nix
    ./nix-minecraft.nix

    ./userconfig.nix
  ];
  
  # # backup can be triggered with sudo systemctl start restic-backups-pcloud.service
  # services.restic.backups.pcloud = {
  #   repository = "rclone:pcloud:/nixpad-backups";
  #   initialize = true;
  #   rcloneConfigFile = "${config.sops.templates."rclone.conf".path}";
  #   passwordFile = "${config.sops.secrets."pcloud/password".path}";
  #   paths = [ "/home/${config.userConfig.username}/nixserver_backup" ];
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
      ${config.userConfig.username} = import ../../home-manager/nixserver/home.nix;
    };
  };

  networking = {
    hostName = "nixserver";
    interfaces = {
      ens3.ipv6 = {
        addresses = [
          {
            address = "2a03:4000:5a:cd::";
            prefixLength = 64;
          }
          {
            address = "2a03:4000:5a:cd:dead:beef:cafe:2d";
            prefixLength = 64;
          }
        ];
      };
    };
    defaultGateway6 = {        
      address = "fe80::1"; 
      interface = "ens3";
    };
  };

  users.users.${config.userConfig.username}.extraGroups = [ "network" "rfkill" "power" "wheel" "docker" ];

  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";
  virtualisation.oci-containers.backend = "docker";

  networking.firewall = {
    allowedTCPPorts = [ 22 80 81 443 7777 ];
    allowedUDPPorts = [ 2757 2759 7777 ];
    # to allow umami to access the umami-db container
    interfaces."docker0".allowedTCPPorts = [ 5000 ];
  };
}
