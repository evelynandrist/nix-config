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

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z

    ./hardware-configuration.nix

    ./kmonad.nix

    ./userconfig.nix
  ];

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
	package = pkgs.qemu;
        runAsRoot = true;
        swtpm.enable = true;
	 ovmf = {
          enable = true;
        };
      };
    };
    docker.enable = true;
    docker.storageDriver = "btrfs";
  };

  # needed for hyprlock
  security.pam.services.hyprlock = { };

  security.pam.yubico = {
    enable = true;
    mode = "challenge-response";
    id = "26701425";
  };

  # for osx-kvm
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  environment.persistence."/persist".directories = [
    "/var/lib/libvirt"
  ];

  # low latency windows 10 vm display
  environment.systemPackages = with pkgs; [
    looking-glass-client
  ];
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 ${config.userConfig.username} qemu-libvirtd -"
  ];

  # backup can be triggered with sudo systemctl start restic-backups-pcloud.service
  services.restic.backups.pcloud = {
    repository = "rclone:pcloud:/nixpad-backups";
    initialize = true;
    rcloneConfigFile = "${config.sops.templates."rclone.conf".path}";
    passwordFile = "${config.sops.secrets."pcloud/password".path}";
    paths = [ "/home/${config.userConfig.username}/nixpad_backup" ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users = {
      # Import your home-manager configuration
      ${config.userConfig.username} = import ../../home-manager/nixpad/home.nix;
    };
  };

  # Needed for internet access in the video-paper module
  nix.settings.sandbox = "relaxed";

  # Bootloader.
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
    efi.canTouchEfiVariables = true;
  };

  # Grub theme
  boot.loader.grub.theme = pkgs.stdenv.mkDerivation {
    pname = "distro-grub-themes";
    version = "3.1";
    src = pkgs.fetchFromGitHub {
      owner = "AdisonCavani";
      repo = "distro-grub-themes";
      rev = "v3.1";
      hash = "sha256-ZcoGbbOMDDwjLhsvs77C7G7vINQnprdfI37a9ccrmPs=";
    };
    installPhase = "cp -r customize/nixos $out";
  };

  networking.hostName = "nixpad"; # Define your hostname.
  # Enable networking
  networking.networkmanager.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.dconf.enable = true; # required for gtk

  users.users.${config.userConfig.username}.extraGroups = [ "networkmanager" "video" "network" "rfkill" "power" "lp" "wheel" "libvirtd" "docker" ];

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
#    extraPackages = with pkgs; [
#      vaapiVdpau
#      libvdpau-va-gl
#    ];
  };

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.udev.packages = [ pkgs.yubikey-personalization ];

  services.pcscd.enable = true; # support YubiKey smart card mode

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --user-menu --user-menu-min-uid 1000 -c Hyprland --time --issue --asterisks";
        user = "greeter";
      };
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      # CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "performance";

      # CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

      #Optional helps save long term battery health
      START_CHARGE_THRESH_BAT0 = 70; # 70 and bellow it starts to charge
      STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
    };
  };

  services.thinkfan = {
    enable = true;
    sensors = [
      {
	type = "hwmon";
	query = "/sys/class/hwmon";
	name = "thinkpad";
	indices = [ 1 2 ];
	correction = [ 0 5 ];
      }
    ];
    fans = [
      {
	type = "tpacpi";
	query = "/proc/acpi/ibm/fan";
      }
    ];
    levels = [
      [ 0 0 50 ]
      [ "level auto" 45 75 ]
      [ 200 70 85 ]
      [ "level disengaged" 80 255 ]
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 22 ]; # ssh
    # wireguard trips rpfilter up
    checkReversePath = false;
   #  # if packets are still dropped, they will show up in dmesg
   #  logReversePathDrops = true;
   #  # wireguard trips rpfilter up
   #  extraCommands = ''
   #   ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
   #   ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
   # '';
   #  extraStopCommands = ''
   #   ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
   #   ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
   # '';
  };
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
