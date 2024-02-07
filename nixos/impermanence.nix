{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  # # Note `lib.mkBefore` is used instead of `lib.mkAfter` here.
  # boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
  #   mkdir -p /mnt

  #   # We first mount the btrfs root to /mnt
  #   # so we can manipulate btrfs subvolumes.
  #   mount -o subvol=/ ${config.fileSystems."/".device} /mnt

  #   # While we're tempted to just delete /root and create
  #   # a new snapshot from /root-blank, /root is already
  #   # populated at this point with a number of subvolumes,
  #   # which makes `btrfs subvolume delete` fail.
  #   # So, we remove them first.
  #   #
  #   # /root contains subvolumes:
  #   # - /root/var/lib/portables
  #   # - /root/var/lib/machines
  #   #
  #   # I suspect these are related to systemd-nspawn, but
  #   # since I don't use it I'm not 100% sure.
  #   # Anyhow, deleting these subvolumes hasn't resulted
  #   # in any issues so far, except for fairly
  #   # benign-looking errors from systemd-tmpfiles.
  #   btrfs subvolume list -o /mnt/root |
  #   cut -f9 -d' ' |
  #   while read subvolume; do
  #     echo "deleting /$subvolume subvolume..."
  #     btrfs subvolume delete "/mnt/$subvolume"
  #   done &&
  #   echo "deleting /root subvolume..." &&
  #   btrfs subvolume delete /mnt/root

  #   echo "restoring blank /root subvolume..."
  #   btrfs subvolume snapshot /mnt/root-blank /mnt/root

  #   # Once we're done rolling back to a blank snapshot,
  #   # we can unmount /mnt and continue on the boot process.
  #   umount /mnt
  # '';

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount ${config.fileSystems."/".device} /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';


  #############################################################################
  #                             Opt-in persistency                            #
  #############################################################################

  /*environment.etc = {
    "NetworkManager/system-connections".source = "/persist/etc/NetworkManager/system-connections";
    adjtime.source = "/persist/etc/adjtime";
    machine-id.source = "/persist/etc/machine-id";
    "static/ssh/ssh_known_hosts".source = "/persist/etc/static/ssh/ssh_known_hosts";
    "ssh/ssh_host_ed25519_key".source = "/persist/etc/ssh/ssh_host_ed25519_key";
    "ssh/ssh_host_ed25519_key.pub".source = "/persist/etc/ssh/ssh_host_ed25519_key.pub";
    "ssh/ssh_host_rsa_key".source = "/persist/etc/ssh/ssh_host_rsa_key";
    "ssh/ssh_host_rsa_key.pub".source = "/persist/etc/ssh/ssh_host_rsa_key.pub";
  };
  systemd.tmpfiles.rules = [
    "L /var/lib/NetworkManager/secret_key - - - - /persist/var/lib/NetworkManager/secret_key"
    "L /var/lib/NetworkManager/seen-bssids - - - - /persist/var/lib/NetworkManager/seen-bssids"
    "L /var/lib/NetworkManager/timestamps - - - - /persist/var/lib/NetworkManager/timestamps"
  ];*/

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/lib/bluetooth"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/adjtime"
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';
}
