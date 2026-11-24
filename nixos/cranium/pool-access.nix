# Who may read and write what on the pools.
#
# Access goes by the mode bits alone: the TrueNAS's NFSv4 ACLs grant
# nothing on Linux (pools.nix). The owners as seen on 2026-11-24, after
# Evelyn's chown and chgrp on the TrueNAS that day:
#
#   dataset         top folder   below it            used here by
#   Photos          568:0 770    568                 Immich, as uid 568
#   Backups/restic  568:0 770    568:0 770           the rest-server, as uid 568
#   Share           3000:0 770   3000 (but one       Evelyn (uid 3000), Samba
#                                leftover, below)
#   Media           0:media 770  group media, not    Jellyfin, media-stack, Evelyn:
#                                world-readable      the group media
#
# 568 is the TrueNAS's `apps`, which all its apps ran as; 3000 is Evelyn's
# uid there, the group `media` (3002) one she made for this. Here:
#   - the user immich has uid and gid 568, and the rest-server runs as that
#     user too, as on the TrueNAS (one uid for both, for now);
#   - Evelyn keeps uid 3000 (configuration.nix);
#   - Jellyfin, media-stack and Evelyn are in the group media. New files
#     written into Media through Samba get that group (`force group`,
#     samba.nix), and mode 770 from the inherited ACL entries, so the others
#     can read them. Jellyfin and the rest-server do not write into Media.
# Share/move_to_dellserver/radicale does not belong to 3000: a leftover,
# left alone.
#
# Nothing here changes owners, modes or ACLs on the pools: that keeps the
# way back to TrueNAS as it is, and on Media and Share a chmod would fail
# anyway (aclmode=restricted). The modules of Immich and the rest-server
# would, at every boot; that is switched off below.
#
# If a chmod from a client through Samba fails on Media or Share (a Mac or
# Windows setting permissions after a copy, an error instead of the copy),
# the way out is ZFS's, per dataset, undone with `aclmode=restricted`:
#   sudo zfs set aclmode=passthrough Neocortex/Media
#
# Later, once Evelyn stays on NixOS and only if wanted: the rest-server as
# its own user `restic` instead of 568 (`chown -R restic:restic` of the
# repositories, then drop the lines for it below). Changing owners is a
# write to the pools; going back to TrueNAS then needs them set back.
{ config, lib, ... }:
let
  username = config.userConfig.username;
in {
  users.users.immich.uid = 568;
  users.groups.immich.gid = 568;

  users.groups.media.gid = 3002;

  # `pools`: into /mnt/Neocortex at all (pools.nix)
  users.users.immich.extraGroups = [ "pools" ];
  users.users.jellyfin.extraGroups = [ "pools" "media" ];
  users.users.media-stack.extraGroups = [ "pools" "media" ];
  users.users.${username}.extraGroups = [ "pools" "media" ];

  # Immich's module: chown immich and chmod 0700 of the library at every boot.
  systemd.tmpfiles.settings.immich = lib.mkForce { };

  # The rest-server as uid 568. Its module makes the data folder the home of
  # `restic` (chown, chmod), and with its option privateRepos it would chown
  # .htpasswd too (rest-server.nix gives the flag instead).
  systemd.services.restic-rest-server.serviceConfig = {
    User = lib.mkForce "immich";
    Group = lib.mkForce "immich";
  };
  users.users.restic.createHome = lib.mkForce false;
}
