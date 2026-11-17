{ config, lib, pkgs, ... }: 
let
  dataDir = "/persist/data/media-stack";
  group = "mediastack";
in {
  # imports = [ ./bitthief.nix ];

  fileSystems."/mnt/neocortexmedia" = {
    device = "//192.168.1.56/Media";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      performance_opts = "vers=3.0,cache=none,rsize=1048576,wsize=1048576,actimeo=30,soft";
      credentials = "username=media-stack,password=thisisnotsecurebutitdoesnotmatter";

    in ["${automount_opts},${credentials},${performance_opts},uid=1000,gid=992,noperm"];
  };

  users.groups."${group}".gid = 992;

  # jellyfin runs on the TrueNAS (jellyfin.qwt.ch in nginx.nix proxies there)

  services.sonarr = {
    enable = true;
    dataDir = "${dataDir}/sonarr";
    group = "${group}";
  };

  services.radarr = {
    enable = true;
    dataDir = "${dataDir}/radarr";
    group = "${group}";
  };

  services.seerr = {
    enable = true;
    configDir = "${dataDir}/jellyseerr";
  };
  # # we need to override some options to use /persist as a data dir since the module doesn't support it
  # systemd.services.seerr.serviceConfig.BindPaths = lib.mkForce [
  #   "${dataDir}/jellyseerr/:${config.services.seerr.package}/share/config/"
  # ];
  systemd.services.seerr.serviceConfig.ReadWritePaths = [ "${dataDir}/jellyseerr/" ];
  systemd.services.seerr.serviceConfig.Group = "${group}";

  services.sabnzbd = {
    enable = true;
    configFile = "${dataDir}/sabnzbd/sabnzbd.ini";
    group = "${group}";
  };
  # Started right at boot, sabnzbd hangs before it writes its first log line
  # and runs into the start timeout; started later it is up within a second.
  # Presumably it waits on the network, so order it after that, and retry in
  # case that is not the whole story.
  systemd.services.sabnzbd = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  systemd.tmpfiles.rules = [
      "d '${dataDir}/jellyseerr' 0770 root ${group} - -"
      "d '${dataDir}/sabnzbd' 0700 sabnzbd ${group} - -"
  ];
}
