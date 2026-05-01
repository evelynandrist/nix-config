{ config, lib, pkgs, ... }: 
let
  configDir = "/persist/data/hass";
in {
  imports = [
  ];

  services.home-assistant = {
    enable = true;
    configDir = "${configDir}";
    extraPackages = ps: with ps; [
      openai
      pysabnzbd
    ];
    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"
      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"

      "samsungtv"
      "hue"
      "mystrom"
      "tuya"
      "wiz"
      "mqtt"

      "sabnzbd"
      "sonarr"
      "radarr"
      "jellyfin"

      "piper"
      "wyoming"
    ];
    customComponents = with pkgs; [
      extended-openai-conversation
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};
      http = {
	server_host = "127.0.0.1";
	trusted_proxies = [ "127.0.0.1" ];
	use_x_forwarded_for = true;
      };
    };
  };

  services.nginx.virtualHosts."home.qwt.ch" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
    };
    extraConfig = ''
      proxy_buffering off;
    '';
  };

  systemd.tmpfiles.rules = [
    "d '${configDir}' 0700 hass hass - -"
  ];
}
