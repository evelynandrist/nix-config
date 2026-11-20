# SMB share for the document scanner (ScanSnap iX1600, "Scan to Network
# Folder"): the scanner writes its PDFs straight into paperless's consume
# folder.
#
#   \\dellserver\consume  ->  /persist/data/paperless/consume
#
# The profile on the scanner saves to a subfolder (consume\evelyn), which
# becomes the owner and the tags, see paperless.nix.
#
# One account, `scanner`, password from sops (paperless/scanner_samba_password). It
# has no shell and no other share. Whatever it writes belongs to
# `paperless`: paperless deletes each file after importing it and fails
# with "Permission denied" on files or folders owned by someone else.
#
# Samba's password database is not kept across reboots (/var/lib/samba is
# not in /persist); the account is created again from the secret at every
# boot.
{ config, pkgs, ... }:
let
  consumeDir = "${config.services.paperless.dataDir}/consume";
  passwordFile = config.sops.secrets."paperless/scanner_samba_password".path;
in {
  sops.secrets."paperless/scanner_samba_password" = { };

  users.users.scanner = {
    isSystemUser = true;
    group = "scanner";
  };
  users.groups.scanner = { };

  services.samba = {
    enable = true;
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        "server string" = "dellserver";
        "server min protocol" = "SMB2";
        # Port 445 only, no NetBIOS.
        "disable netbios" = "yes";
        "smb ports" = "445";
        "map to guest" = "Never";
        "load printers" = "no";
      };

      consume = {
        path = consumeDir;
        "valid users" = "scanner";
        "read only" = "no";
        "force user" = config.services.paperless.user;
        "force group" = config.users.users.${config.services.paperless.user}.group;
        "create mask" = "0640";
        "directory mask" = "0750";
      };
    };
  };

  systemd.services.samba-scanner-password = {
    description = "Set the Samba password of the scanner account";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "samba-smbd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      pw=$(cat ${passwordFile})
      printf '%s\n%s\n' "$pw" "$pw" | ${pkgs.samba}/bin/smbpasswd -s -a scanner
    '';
  };

  networking.firewall.allowedTCPPorts = [ 445 ];
}
