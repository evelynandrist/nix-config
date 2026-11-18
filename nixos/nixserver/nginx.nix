{ config, lib, pkgs, ... }:
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
    cloudflareRanges = lib.filter (range: range != "")
      (lib.concatMap (file: lib.strings.splitString "\n" (builtins.readFile "${file}"))
        [ cloudflareIPv4s cloudflareIPv6s ]);
in {
  # vault, books and the webmail are reached directly, budget and search
  # through Cloudflare. Left open on purpose: Minecraft (mc, voice.mc) and
  # the rickroll (rr, holysnit.ch). Mail itself (SMTP, IMAP) does not go
  # through nginx and stays open to every country.
  hardening.geoBlock = {
    sites = [ "vault.qwt.ch" "books.qwt.ch" "mail.andrist.dev" ];
    cloudflareSites = [ "budget.qwt.ch" "search.qwt.ch" ];
  };

  services.fail2ban.ignoreIP =
    # Requests to the proxied sites all come from these addresses; a ban
    # would take the site down for everyone.
    cloudflareRanges
    # home (DDNS record), so a typo there never locks the VPS away
    ++ [ "orchard.qwt.ch" ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "_" = {
	globalRedirect = "rr.qwt.ch";
	# extraConfig = ''
	#   ${allowCloudflareIPv4s}
	#   ${allowCloudflareIPv6s}
	#   deny all; # block all remaining ips
	# '';
      };
      "holysnit.ch" = {
	globalRedirect = "rr.qwt.ch";
	extraConfig = ''
	  ${allowCloudflareIPv4s}
	  ${allowCloudflareIPv6s}
	  deny all; # block all remaining ips
	'';
      };
      "budget.qwt.ch" = {
	locations."/" = {
	  proxyPass = "http://127.0.0.1:31012";
	};
	extraConfig = ''
	  ${allowCloudflareIPv4s}
	  ${allowCloudflareIPv6s}
	  deny all; # block all remaining ips
	'';
      };
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
 #      "legends.qwt.ch" = {
	# locations."/" = {
	#   proxyPass = "http://127.0.0.1:8203";
	# };
	# extraConfig = ''
	#   ${allowCloudflareIPv4s}
	#   ${allowCloudflareIPv6s}
	#   deny all; # block all remaining ips
	# '';
 #      };
      "vault.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:8002";
	  recommendedProxySettings = true;
	};
	extraConfig = ''
	  client_max_body_size 500M;
	'';
      };
      "books.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://[::1]:8004";
	  recommendedProxySettings = true;
	};
	extraConfig = ''
	  client_max_body_size 500M;
	'';
      };
 #      "asf.qwt.ch" = {
	# locations."/" = {
	#   proxyPass = "http://127.0.0.1:1242";
	# };
	# extraConfig = ''
	#   ${allowCloudflareIPv4s}
	#   ${allowCloudflareIPv6s}
	#   deny all; # block all remaining ips
	# '';
 #      };
 #      "chat.qwt.ch" = {
	# locations."/" = {
	#   proxyPass = "http://127.0.0.1:8005";
	# };
	# extraConfig = ''
	#   ${allowCloudflareIPv4s}
	#   ${allowCloudflareIPv6s}
	#   deny all; # block all remaining ips
	# '';
 #      };
 #      "post-email.qwt.ch" = {
	# enableACME = true;
	# forceSSL = true;
	# locations."/" = {
	#   proxyPass = "http://127.0.0.1:8006";
	#   recommendedProxySettings = true;
	# };
 #      };
      "mail.andrist.dev" = {
	enableACME = true;
      };
      "rr.qwt.ch" = {
	root = ./rickroll;
	extraConfig = ''
	  ${allowCloudflareIPv4s}
	  ${allowCloudflareIPv6s}
	  deny all; # block all remaining ips
	'';
      };
 #      "banjomin.ch" = {
	# enableACME = true;
	# forceSSL = true;
	# root = "/persist/data/banjomin";
 #      };
 #      "photos.qwt.ch" = {
	# enableACME = true;
	# forceSSL = true;
	# locations."/" = {
	#   proxyPass = "http://127.0.0.1:2283";
	#   proxyWebsockets = true;
	# };
	# extraConfig = ''
	#   # allow large file uploads
	#   client_max_body_size 50000M;
	#
	#   # set timeout
	#   proxy_read_timeout 600s;
	#   proxy_send_timeout 600s;
	#   send_timeout       600s;
	# '';
 #      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "evelyn@andrist.dev";
  };
}
