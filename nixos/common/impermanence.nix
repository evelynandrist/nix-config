{ config, lib, pkgs, inputs, utils, ... }:
let
  rootDevice = config.fileSystems."/".device;
  rootDeviceUnit = "${utils.escapeSystemdPath rootDevice}.device";
in {
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  #############################################################################
  #                                Wipe script                                #
  #############################################################################

  # On every boot, move the root subvolume to old_roots/<timestamp> and
  # create a fresh, empty one. Old roots are deleted after 30 days.
  #
  # This runs as a service in the systemd stage 1 (scripted stage 1 and its
  # postDeviceCommands were removed from nixpkgs): after the disk has shown
  # up and before / is mounted at /sysroot.
  boot.initrd.systemd.initrdBin = [ pkgs.findutils ]; # `find` for the cleanup
  boot.initrd.systemd.services.rollback-root = {
    description = "Archive the old root subvolume and create a fresh one";
    wantedBy = [ "initrd.target" ];
    requires = [ rootDeviceUnit ];
    after = [ rootDeviceUnit ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /btrfs_tmp
      mount ${rootDevice} /btrfs_tmp
      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      # Create the new root before the cleanup, so that a failed cleanup can
      # never leave the system without a root to mount.
      btrfs subvolume create /btrfs_tmp/root

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
      }

      # -mindepth 1: never match old_roots itself
      for i in $(find /btrfs_tmp/old_roots/ -mindepth 1 -maxdepth 1 -mtime +30); do
          delete_subvolume_recursively "$i" || echo "rollback-root: failed to delete $i" >&2
      done

      umount /btrfs_tmp
    '';
  };


  #############################################################################
  #                             Opt-in persistency                            #
  #############################################################################

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      # systemd state: timer stamps, backlight/rfkill state, coredumps and
      # credential.secret. Without the latter, anything encrypted with
      # systemd-creds (e.g. libvirt's secrets-encryption-key in the persisted
      # /var/lib/libvirt) can't be decrypted after a reboot.
      "/var/lib/systemd"
      "/var/lib/acme" # certs + ACME account; otherwise re-ordered on every boot
      "/var/lib/bluetooth"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/adjtime"
      "/etc/machine-id"
    ];
  };

  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';
}
