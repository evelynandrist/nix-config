{ config, lib, pkgs, ... }: {
  services.nginx =
  let
    cloudflareIPv4s = builtins.fetchurl {
      url = "https://www.cloudflare.com/ips-v4";
      sha256 = "0ywy9sg7spafi3gm9q5wb59lbiq0swvf0q3iazl0maq1pj1nsb7h";
    };
    cloudflareIPv6s = builtins.fetchurl {
      url = "https://www.cloudflare.com/ips-v6";
      sha256 = "1ad09hijignj6zlqvdjxv7rjj8567z357zfavv201b9vx3ikk7cy";
    };
    allowCloudflareIPv4s =
      lib.concatMapStrings (ip: "allow ${ip};\n")
	(lib.strings.splitString "\n" (builtins.readFile "${cloudflareIPv4s}"));
    allowCloudflareIPv6s =
      lib.concatMapStrings (ip: "allow ${ip};\n")
	(lib.strings.splitString "\n" (builtins.readFile "${cloudflareIPv6s}"));
  in {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "search.qwt.ch" = {
	locations."/" = {
	  proxyPass = "http://127.0.0.1:8001";
	};
	extraConfig = ''
	  ${allowCloudflareIPv4s}
	  ${allowCloudflareIPv6s}
	  deny all; # block all remaining ips
	'';
      };
      "vault.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:8002";
	};
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "kevin1bam@web.de";
  };
}
