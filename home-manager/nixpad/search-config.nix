{pkgs, ...}: {
  force = true;
  default = "SearXNG";
  privateDefault = "SearXNG";
  engines = let
    nixSnowflakeIcon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  in {
    "SearXNG" = {
      urls = [
	{
	  template = "https://search.qwt.ch/search";
	  params = [
	    {
	      name = "q";
	      value = "{searchTerms}";
	    }
	  ];
	}
      ];
      definedAliases = ["@searxng" "@sx"];
      icon = "https://search.qwt.ch/static/themes/simple/img/favicon.png";
      updateInterval = 24 * 60 * 60 * 1000;
    };
    "Nix Packages" = {
      urls = [
        {
          template = "https://search.nixos.org/packages";
          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "channel";
              value = "unstable";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = nixSnowflakeIcon;
      definedAliases = ["@pkgs"];
    };
    "Nix Options" = {
      urls = [
        {
          template = "https://search.nixos.org/options";
          params = [
            {
              name = "channel";
              value = "unstable";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      icon = nixSnowflakeIcon;
      definedAliases = ["@nop"];
    };
    "Home Manager Options" = {
      urls = [
        {
          template = "https://home-manager-options.extranix.com/";
          params = [
            {
              name = "query";
              value = "{searchTerms}";
            }
            {
              name = "release";
              value = "master"; # unstable
            }
          ];
        }
      ];
      icon = nixSnowflakeIcon;
      definedAliases = ["hmop"];
    };

    "Google Maps" = {
      urls = [
        {
          template = "http://maps.google.com";
          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      definedAliases = ["@maps" "@gmaps"];
    };
    "StartPage" = {
      urls = [
        {
          template = "https://www.startpage.com/sp/search";
          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      definedAliases = ["@startpage" "@sp" "@pp"];
      icon = "https://www.startpage.com/sp/cdn/favicons/favicon-gradient.ico";
      updateInterval = 24 * 60 * 60 * 1000;
    };
    "ddg" = {
      urls = [
        {
          template = "https://duckduckgo.com";
          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      definedAliases = ["@duck" "@ddg" "@dck" "@dckk"];
    };

    # bing.metaData.hidden = "true";
  };
}
