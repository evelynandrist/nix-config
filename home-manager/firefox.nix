{ config, lib, pkgs, inputs, ... }: {
  imports = [
    inputs.nur.hmModules.nur
  ];
  home.file.".mozilla/firefox/${config.userConfig.username}/chrome".source = "${inputs.WaveFox}/chrome";

  programs.firefox = {
    enable = true;
    profiles.${config.userConfig.username} = {
      extensions = with config.nur.repos.rycee.firefox-addons; [
        bitwarden
        ublock-origin
        vimium-c
      ];
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "svg.context-properties.content.enabled" = true;
        "userChrome.Tabs.Option12.Enabled" = true;
        "userChrome.Linux.Transparency.VeryHigh.Enabled" = true;
        "gfx.webrender.all" = true;
        "browser.tabs.inTitlebar" = 1;
      };
      search = {
        engines = {
          "SearXNG" = {
            urls = [{ template = "https://search.qwt.ch/search?q={searchTerms}"; }];
            iconUpdateURL = "https://search.qwt.ch/favicon.ico";
            updateInterval = 24 * 60 * 60 * 1000; # every day
          };
          "Bing".metaData.hidden = true;
        };
        default = "SearXNG";
        privateDefault = "SearXNG";
        force = true; # replace existing config
      };
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };
}
