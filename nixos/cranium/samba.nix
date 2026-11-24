# The two SMB shares of the TrueNAS:
#
#   \\truenas\Share  ->  /mnt/Neocortex/Share   Evelyn
#   \\truenas\Media  ->  /mnt/Neocortex/Media   Evelyn, media-stack
#
# media-stack is the account packardserver mounts Media with (Sonarr and
# Radarr write there, ../packardserver/media-stack.nix). It keeps its
# TrueNAS uid, 3003, as Evelyn keeps 3000 (configuration.nix).
#
# Media is shared through the group media (pool-access.nix): whatever
# Evelyn or media-stack write there gets that group (`force group`), so
# Jellyfin and the other account can read it. The mode, 770, comes from the
# folder's inherited ACL entries, not from Samba.
#
# A client that sets permissions (a Mac or Windows after a copy) makes
# Samba chmod, which ZFS refuses on Media and Share (aclmode=restricted,
# pools.nix). The way out is in pool-access.nix.
#
# The Samba passwords are sops secrets, set again at every boot (Samba's
# password database is not kept, as on dellserver). Evelyn's is the one she
# uses for the share today, so no laptop changes; media-stack's has to be
# the one in ../packardserver/media-stack.nix.
#
# streams_xattr, as TrueNAS has it: Windows and macOS keep extra data of a
# file (Finder tags, for one) in extended attributes, and without it what
# TrueNAS stored that way is no longer seen.
{ config, pkgs, lib, ... }:
let
  username = config.userConfig.username;
  accounts = {
    ${username} = "samba/evelyn_password";
    media-stack = "samba/media_stack_password";
  };
  share = path: users: {
    inherit path;
    "valid users" = users;
    "read only" = "no";
    "vfs objects" = "streams_xattr";
  };
in {
  sops.secrets = lib.mapAttrs' (_: secret: lib.nameValuePair secret { }) accounts;

  users.users.media-stack = {
    isSystemUser = true;
    uid = 3003;
    group = "media-stack";
  };
  users.groups.media-stack.gid = 3003;

  services.samba = {
    enable = true;
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        "server string" = config.networking.hostName;
        "server min protocol" = "SMB2";
        # Port 445 only, no NetBIOS.
        "disable netbios" = "yes";
        "smb ports" = "445";
        "map to guest" = "Never";
        "load printers" = "no";
      };

      Share = share "/mnt/Neocortex/Share" username;
      Media = share "/mnt/Neocortex/Media" "${username} media-stack" // {
        "force group" = "media";
      };
    };
  };

  systemd.services.samba-passwords = {
    description = "Set the Samba passwords";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "samba-smbd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatStrings (lib.mapAttrsToList (user: secret: ''
      pw=$(cat ${config.sops.secrets.${secret}.path})
      printf '%s\n%s\n' "$pw" "$pw" | ${pkgs.samba}/bin/smbpasswd -s -a ${user}
    '') accounts);
  };

  networking.firewall.allowedTCPPorts = [ 445 ];
}
