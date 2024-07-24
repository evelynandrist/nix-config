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


  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXIHguo2D+mPHhGFrQKJRZFsDdAN0ETCCfTWpJYUKgi" # ssh key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPU9h8nXlYgAmdVbRr3uzuEipNtJDbPGcbbuNr3YRaxJ" # gpg key
  ];

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

  networking.firewall = {
    allowedTCPPorts = [ 22 80 81 443 7777 ];
    allowedUDPPorts = [ 7777 ];
  };
}
