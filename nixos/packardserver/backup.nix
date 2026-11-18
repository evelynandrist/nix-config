{ config, lib, pkgs, ... }:
let
  # rest-server app on the TrueNAS, started with --private-repos
  restServer = "http://truenas.internal.qwt.ch:30080";
in {
  imports = [ ../common/truenas-backup.nix ];

  # All state lives in /persist (impermanence).
  services.restic.backups.truenas = {
    paths = [ "/persist" ];
    exclude = [
      # can be regenerated
      "/persist/data/media-stack/jellyfin/cache"
      "/persist/data/media-stack/jellyfin/data/transcodes"
    ];
  };

  # The way in for hosts outside the LAN (nixserver, nixpad on the road).
  # Logins are checked by the rest-server itself (its .htpasswd).
  services.nginx.virtualHosts."backup.qwt.ch" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = restServer;
    extraConfig = ''
      # restic uploads pack files of any size, stream them through
      client_max_body_size 0;
      proxy_request_buffering off;

      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
      send_timeout       600s;
    '';
  };

  # This host serves both names itself. Without this it would go out to the
  # router and back in (if the router does hairpin NAT at all).
  networking.hosts."127.0.0.1" = [ "backup.qwt.ch" "home.qwt.ch" ];
}
