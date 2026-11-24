# The two ZFS pools from the TrueNAS, imported as they are.
#
#   Neocortex  raidz1 of three 16 TB disks (USB): Photos, Media, Share, Backups
#   Thalamus   one 2 TB SSD (USB), no redundancy: the TrueNAS's app data
#
# The TrueNAS's boot-pool, on a third USB disk, is never imported here.
#
# Never run `zpool upgrade` on them: the pools have no feature newer than
# OpenZFS 2.2, which is what keeps the way back to TrueNAS open. NixOS does
# not upgrade by itself; `zpool status` suggests it, ignore that.
#
# The host id is the TrueNAS's (`hostid` there, 2026-11-24). ZFS refuses to
# import a pool last used by another host id without -f; with the same one,
# NixOS and TrueNAS both import the pools as their own and the way back
# needs no forced import.
#
# What NixOS writes to the pools without being asked: the import itself, a
# property nixos:shutdown-time at every shutdown (zfs-sync-<pool>), the
# snapshots below and the `zfs allow` that sanoid sets for itself. Nothing
# that TrueNAS would mind. No owners, modes or ACLs (pool-access.nix). No
# TRIM (on by default in NixOS, off on the TrueNAS): the HDDs have none and
# the SSD is behind USB.
#
# TrueNAS imports the pools under /mnt (altroot), so their own mountpoints
# are /Neocortex, /.ix-apps and so on, and both pools have an ix-apps with
# the same one. Instead of mounting everything there (`zfs mount -a`, off
# below), only the datasets the services use are mounted, at the paths they
# had on the TrueNAS. `zfsutil` mounts a dataset at a path other than its
# mountpoint without changing the property. `nofail`: a USB disk that does
# not come up must not stop the boot (no network, no ssh). The services
# that use a dataset require its mount (RequiresMountsFor), so they do not
# start on an empty folder of the root file system.
#
# /mnt/Neocortex (a folder on the NVMe, not on the pool) is only open to the
# group `pools`: the services, Evelyn and media-stack, not `agent`.
#
# Photos, Media, Share and Backups/restic still carry the TrueNAS's NFSv4
# ACLs (acltype=nfsv4, aclinherit=passthrough). On Linux, OpenZFS treats
# that acltype as off: access goes by the mode bits alone, the stored entries
# grant nothing and practically never refuse (only an explicit deny entry on
# delete would count; nobody has looked for one). They still set the mode of
# new files: a new file or folder inherits its folder's entries, and its mode
# is computed from them, not from the umask: 770 here, for files too. With
# aclmode=restricted (Media, Share) a chmod of anything with such an ACL
# fails with EPERM, for root too; Photos and Backups/restic have
# aclmode=passthrough. Read in the OpenZFS 2.4.4 source, not tried. Who gets
# in where: pool-access.nix.
#
# Snapshots: sanoid, daily, kept 30 days, of Backups/restic as on the TrueNAS
# (what ../common/truenas-backup.nix relies on), and of Photos and Share
# (new, Evelyn's decision). Media and Thalamus have none.
# The TrueNAS's own auto-* snapshots are left alone and do not expire: delete
# them by hand once the way back is no longer needed.
#
# A pool that is missing or not healthy fails zpool-health, which tells
# Home Assistant (ha-notify-failed@, ../common/auto-upgrade.nix).
#
#   zpool status;  zfs list -t snapshot Neocortex/Photos
#   sudo systemctl start zpool-health;  journalctl -u sanoid
{ config, lib, pkgs, ... }:
let
  pools = [ "Neocortex" "Thalamus" ];
  dataset = name: extraOptions: {
    device = name;
    fsType = "zfs";
    options = [ "zfsutil" "nofail" ] ++ extraOptions;
  };
in {
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # the TrueNAS's, see above
  networking.hostId = "0aea1436";

  fileSystems = {
    "/mnt/Neocortex/Photos" = dataset "Neocortex/Photos" [ ];
    "/mnt/Neocortex/Media" = dataset "Neocortex/Media" [ ];
    "/mnt/Neocortex/Share" = dataset "Neocortex/Share" [ ];
    "/mnt/Neocortex/Backups/restic" = dataset "Neocortex/Backups/restic" [ ];
    # The TrueNAS's app data: read at the cutover, never written.
    "/mnt/Thalamus/Apps" = dataset "Thalamus/Apps" [ "ro" ];
  };

  systemd.services.zfs-mount.enable = false;

  users.groups.pools = { };
  systemd.tmpfiles.rules = [
    "d /mnt/Neocortex 0750 root pools -"
    # the TrueNAS's app data includes wg-easy's private keys
    "d /mnt/Thalamus 0700 root root -"
  ];

  services.zfs.trim.enable = false;

  services.zfs.autoScrub = {
    enable = true;
    inherit pools;
    # first Sunday of the month
    interval = "Sun *-*-01..07 03:00";
  };

  services.sanoid = {
    enable = true;
    templates.daily = {
      hourly = 0;
      daily = 30;
      monthly = 0;
      yearly = 0;
      autosnap = true;
      autoprune = true;
    };
    datasets = lib.genAttrs [
      "Neocortex/Backups/restic"
      "Neocortex/Photos"
      "Neocortex/Share"
    ] (_: { useTemplate = [ "daily" ]; });
  };

  systemd.services.zpool-health = {
    description = "Check that the pools are imported and healthy";
    startAt = "09:00";
    path = [ config.boot.zfs.package ];
    unitConfig.OnFailure = [ "ha-notify-failed@%n.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      zpool list ${toString pools} > /dev/null
      status=$(zpool status -x)
      if [ "$status" != "all pools are healthy" ]; then
        echo "$status"
        exit 1
      fi
    '';
  };
}
