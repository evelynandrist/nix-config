{ config, lib, pkgs, ... }: 
let
  dataDir = "/persist/data/media-stack";
  group = "mediastack";
in {
  users.groups."${group}" = {};

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

  services.jellyseerr.enable = true;
  # we need to override some options to use /persist as a data dir since the module doesn't support it
  systemd.services.jellyseerr.serviceConfig.BindPaths = lib.mkForce [
    "${dataDir}/jellyseerr/:${config.services.jellyseerr.package}/libexec/jellyseerr/deps/jellyseerr/config/"
  ];
  systemd.services.jellyseerr.serviceConfig.ReadWritePaths = [ "${dataDir}/jellyseerr/" ];
  systemd.services.jellyseerr.serviceConfig.Group = "${group}";

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
