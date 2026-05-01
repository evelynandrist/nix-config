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

  services.jellyfin = {
    enable = true;
    cacheDir = "${dataDir}/jellyfin/cache";
    configDir = "${dataDir}/jellyfin/config";
    dataDir = "${dataDir}/jellyfin/data";
    logDir = "${dataDir}/jellyfin/log";
    group = "${group}";
  };

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

  systemd.tmpfiles.rules = [
      "d '${dataDir}/jellyseerr' 0770 root ${group} - -"
      "d '${dataDir}/sabnzbd' 0700 sabnzbd ${group} - -"
  ];


  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];
}
