{ config, lib, pkgs, ... }: 
let
  configDir = "/persist/data/hass";
in {
  imports = [
    ./briefing.nix
  ];

  services.home-assistant = {
    enable = true;
    configDir = "${configDir}";
    # not using the module default (overrideAttrs doInstallCheck = false), that misses
    # the binary cache and rebuilds home-assistant locally. the plain package is cached.
    # from nixpkgs-master (locked to a nixos-unstable rev, so it's cached) for
    # 2026.10: 2026.8 used CARTO map tiles, which now need an API key.
    # back to pkgs.home-assistant once the main nixpkgs input has >= 2026.10
    package = pkgs.master.home-assistant.override {
      packageOverrides = self: super: {
        # pywizlight 0.6.6 changed Bulb.state to a list, HA 2026.10 still expects 0.6.3
        pywizlight = super.pywizlight.overridePythonAttrs (old: rec {
          version = "0.6.3";
          src = pkgs.fetchFromGitHub {
            owner = "sbidy";
            repo = "pywizlight";
            tag = "v${version}";
            hash = "sha256-rCoWdqvFLSLNBAHeFJ6f9kZpIg4WyE8VJLpmsYl+gJM=";
          };
        });
      };
    };
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
      "spotify"
      "hue"
      "mystrom"
      "tuya"
      "webostv"
      "wiz"
      "mqtt"

      "ollama"
      "remote_calendar"

      "sabnzbd"
      "sonarr"
      "radarr"
      "jellyfin"

      "piper"
      "wyoming"
    ];
    customComponents = with pkgs; [
      # extended-openai-conversation
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = {};
      "automation ui" = "!include automations.yaml";
      "scene ui"      = "!include scenes.yaml";
      "script ui"     = "!include scripts.yaml";
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
    "f '${configDir}/automations.yaml' 0600 hass hass - -"
    "f '${configDir}/scenes.yaml'      0600 hass hass - -"
    "f '${configDir}/scripts.yaml'     0600 hass hass - -"
  ];
}
