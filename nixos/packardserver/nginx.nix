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
      "_" = {
	globalRedirect = "rr.qwt.ch";
	default = true;
      };
      "photos.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://192.168.1.56:30041";
	  proxyWebsockets = true;
	};
	extraConfig = ''
	  # allow large file uploads
	  client_max_body_size 50000M;

	  # set timeout
	  proxy_read_timeout 600s;
	  proxy_send_timeout 600s;
	  send_timeout       600s;
	'';
      };
 #      "jellyfin.qwt.ch" = {
	# enableACME = true;
	# forceSSL = true;
	# locations."/" = {
	#   proxyPass = "http://127.0.0.1:8096";
	#   proxyWebsockets = true;
	# };
 #      };
      "jellyfin.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://192.168.1.56:30013";
	  proxyWebsockets = true;
	};
      };
      "sonarr.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:8989";
	};
      };
      "radarr.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:7878";
	};
      };
      "jellyseerr.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:5055";
	};
      };
      "sabnzbd.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:8080";
	};
      };
      "fish-speech.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://192.168.1.56:7862";
	};
	extraConfig = ''
	  allow 140.238.214.181;
	  deny all; # block all remaining ips
	'';
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "evelyn@andrist.dev";
  };
}
