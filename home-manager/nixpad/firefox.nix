{ config, lib, pkgs, inputs, ... }: {
  imports = [
    inputs.nur.hmModules.nur
  ];
  home.file.".mozilla/firefox/${config.userConfig.username}/chrome".source = "${inputs.WaveFox}/chrome";

  programs.firefox = {
    enable = true;
    policies = {
      PasswordManagerEnabled = false;
      DefaultDownloadDirectory = "$HOME/Downloads";
      DisableTelemetry = true;
    };
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

        # Disable Pocket
        "browser.newtabpage.activity-stream.feeds.discoverystreamfeed" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "extensions.pocket.enabled" = false;

        "identity.fxaccounts.enabled" = false;
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.shortcuts.bookmarks" = false;
        "browser.urlbar.shortcuts.history" = false;
        "browser.urlbar.shortcuts.tabs" = false;
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.uidensity" = 1;
        "browser.formfill.enable" = false;
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
