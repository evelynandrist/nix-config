{ config, lib, pkgs, ... }: {
  services.searx = {
    enable = true;
    settings = {
      server = {
	base_url = "@SEARX_URL@";
	port = 8001;
	bind_address = "127.0.0.1";
	secret_key = "@SEARX_SECRET_KEY@";
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
    };
  };
}
