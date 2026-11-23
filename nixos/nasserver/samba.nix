# The two SMB shares of the TrueNAS:
#
#   \\truenas\Share  ->  /mnt/Neocortex/Share   Evelyn
#   \\truenas\Media  ->  /mnt/Neocortex/Media   Evelyn, media-stack
#
# media-stack is the account packardserver mounts Media with (Sonarr and
# Radarr write there, ../packardserver/media-stack.nix). It keeps its
# TrueNAS uid, 3003, as Evelyn keeps 3000 (configuration.nix), so the files
# on the pool stay theirs.
#
# The Samba passwords are sops secrets, set again at every boot (Samba's
# password database is not kept, as on dellserver). media-stack's has to be
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

  users.users.${username}.extraGroups = [ "pools" ];
  users.users.media-stack.extraGroups = [ "pools" ];

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
      Media = share "/mnt/Neocortex/Media" "${username} media-stack";
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
