# The NAS: the laptop that ran TrueNAS, now on NixOS. DRAFT: built, never
# installed.
#
# `nasserver` is a placeholder name. To rename: `git grep -l nasserver`,
# move nixos/nasserver and home-manager/nasserver, and rename the sops
# paths backup/nasserver/* (../common/truenas-backup.nix takes them from
# the host name).
#
# NixOS is on the internal NVMe, with the same btrfs layout and impermanence
# as the other hosts (README, pre-install.sh). The TrueNAS boot SSD stays as
# it is: choosing it in the firmware's boot menu is the way back.
#
# The host keeps 192.168.1.56 (from the router, a DHCP reservation for its
# network card, as for the other hosts) and the TrueNAS's ports (Immich 30041,
# Jellyfin 30013, rest-server 30080), so the other hosts reach it as
# before, under the old name truenas.internal.qwt.ch too
# (../common/lan-hosts.nix).
#
#   pools.nix           the two ZFS pools: import, mounts, scrubs, snapshots
#   truenas-owners.nix  until the owners on the pools are changed (last step)
#   immich.nix, jellyfin.nix, rest-server.nix, mosquitto.nix, samba.nix,
#   wg-easy.nix         one file per service, each says what it needs from
#                       the TrueNAS at the cutover
#
# App state lives in /persist on the NVMe, copied from the TrueNAS's
# Thalamus/Apps at the cutover. Copied, not moved: the TrueNAS's own data
# stays as it was, for the way back.
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
    ../common/agent-access.nix

    ./hardware-configuration.nix
    ./userconfig.nix

    ./pools.nix
    ./truenas-owners.nix
    ./immich.nix
    ./jellyfin.nix
    ./rest-server.nix
    ./mosquitto.nix
    ./samba.nix
    ./wg-easy.nix
  ];

  networking.hostName = "nasserver";

  # REMOVE once this host's secrets are in secrets/secrets.yaml (backup/,
  # samba/, mosquitto/). Until then the build would fail on them: the check
  # looks up every secret in the file.
  sops.validateSopsFiles = false;

  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };
    efi.canTouchEfiVariables = true;
  };

  # Stock kernel instead of zen (set in the common config): ZFS and the
  # nvidia module are built and cached for it.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # A laptop used as a server: it runs with the lid closed, and the screen
  # goes dark after a minute when someone does open it.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  boot.kernelParams = [ "consoleblank=60" ];

  # GTX 1060 Mobile (Pascal), for Jellyfin and Immich. Pascal is not
  # supported by the open kernel module nor by the current driver branch;
  # 580 is the last branch that has it. There is no X server; this option is
  # still what turns the driver on. The Intel GPU stays unused.
  # A flake bump that changes the driver is switched to at night but the old
  # kernel module stays loaded: NVENC fails until the next reboot.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  # Evelyn's files on the pools belong to uid 3000, her uid on the TrueNAS.
  users.users.${config.userConfig.username} = {
    uid = 3000;
    extraGroups = [ "network" "rfkill" "power" "wheel" ];
  };

  # All state lives in /persist (impermanence). The database is left out:
  # copying the files of a running PostgreSQL does not give a usable copy.
  # Immich dumps it every night into its own folder on the pool instead
  # (immich.nix).
  services.restic.backups.truenas = {
    paths = [ "/persist" ];
    exclude = [
      "/persist/var/lib/postgresql"
      # downloaded again
      "/persist/var/cache/immich"
      # images, pulled again
      "/persist/var/lib/containers"
    ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users.${config.userConfig.username} = import ../../home-manager/nasserver/home.nix;
  };

  # allow deploying from other machines (nh os switch --target-host), wheel can sudo anyway
  nix.settings.trusted-users = [ "root" "@wheel" ];

  networking.firewall.allowedTCPPorts = [ 22 ];
}
