{ config, lib, pkgs, inputs, ... }: {
  imports = [
    inputs.nur.modules.homeManager.default
    # Ensure this input matches the name in your flake.nix
    inputs.zen-browser.homeModules.default 
  ];

  programs.zen-browser = {
    enable = true;
    # If the flake provides a specific package, it's usually handled by the module, 
    # but you can be explicit:
    # package = inputs.zen-browser.packages.${pkgs.system}.default;

    policies = {
      PasswordManagerEnabled = false;
      DefaultDownloadDirectory = "$HOME/Downloads";
      DisableTelemetry = true;
    };

    profiles.${config.userConfig.username} = {
      # The Zen module uses the same structure as the Firefox module
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
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
            updateInterval = 24 * 60 * 60 * 1000;
          };
          "Bing".metaData.hidden = true;
          "Google".metaData.hidden = true; # Zen usually has Google default
        };
        default = "SearXNG";
        privateDefault = "SearXNG";
        force = true;
      };
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "zen.desktop" ];
    "text/xml" = [ "zen.desktop" ];
    "x-scheme-handler/http" = [ "zen.desktop" ];
    "x-scheme-handler/https" = [ "zen.desktop" ];
    "x-scheme-handler/about" = [ "zen.desktop" ];
    "x-scheme-handler/unknown" = [ "zen.desktop" ];
  };
}
