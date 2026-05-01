{ config, lib, pkgs, ... }: {
  sops.secrets = {
    "searx/base_url" = { };
    "searx/secret_key" = { };
  };

  sops.templates."searx.env" = {
    content = ''
      SEARXNG_BASE_URL=${config.sops.placeholder."searx/base_url"}
      SEARXNG_SECRET=${config.sops.placeholder."searx/secret_key"}
    '';
  };


  services.searx = {
    enable = true;
    environmentFile = config.sops.templates."searx.env".path;
    settings = {
      server = {
	port = 8001;
	bind_address = "127.0.0.1";
	image_proxy = true;
      };
      search = {
	autocomplete = "duckduckgo";
	formats = [
	  "html"
	  "csv"
	  "json"
	  "rss"
	];
      };
      enabled_plugins = [
	"Open Access DOI rewrite"
      ];
      default_doi_resolver = "sci-hub.se";
      engines = [
	{
	  name = "google";
	  engine = "google";
	  shortcut = "go";
	  use_mobile_ui = true;
	}
	{
	  name = "bing";
	  engine = "bing";
	  shortcut = "bi";
	  disabled = false;
	}
      ];
    };
  };
}
