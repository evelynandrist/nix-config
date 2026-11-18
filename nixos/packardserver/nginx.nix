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

    # Sites under internal.qwt.ch: LAN and VPN only. nginx also answers on
    # the public address, so without the allow/deny anyone who guesses a name
    # gets in. Names without a site here end up at the catch-all below (the
    # wildcard record sends all of *.internal.qwt.ch to this host).
    internalRanges = [ "192.168.1.0/24" ];
    internalSite = { upstream, websockets ? false, extraConfig ? "" }: {
      useACMEHost = "internal.qwt.ch";
      forceSSL = true;
      locations."/" = {
        proxyPass = upstream;
        proxyWebsockets = websockets;
      };
      extraConfig = ''
        ${lib.concatMapStrings (range: "allow ${range};\n") internalRanges}
        deny all;
        ${extraConfig}
      '';
    };
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
	  proxyPass = "http://truenas.internal.qwt.ch:30041";
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
	  proxyPass = "http://truenas.internal.qwt.ch:30013";
	  proxyWebsockets = true;
	};
      };
      "sonarr.internal.qwt.ch" = internalSite { upstream = "http://127.0.0.1:8989"; };
      "radarr.internal.qwt.ch" = internalSite { upstream = "http://127.0.0.1:7878"; };
      "jellyseerr.qwt.ch" = {
	enableACME = true;
	forceSSL = true;
	locations."/" = {
	  proxyPass = "http://127.0.0.1:5055";
	};
      };
      "sabnzbd.internal.qwt.ch" = internalSite { upstream = "http://127.0.0.1:8080"; };
      "nas.internal.qwt.ch" = internalSite {
        upstream = "http://truenas.internal.qwt.ch";
        websockets = true;
      };
      "radicale.internal.qwt.ch" = internalSite {
        upstream = "http://127.0.0.1:5232";
        # imports of whole calendars or address books
        extraConfig = "client_max_body_size 100M;";
      };
      "mainsail.internal.qwt.ch" = internalSite {
        upstream = "http://anycubic.internal.qwt.ch";
        websockets = true;
        # gcode uploads
        extraConfig = "client_max_body_size 0;";
      };
    };
  };

  # Everything public on this host. home and backup are defined in
  # home-assistant/ and backup.nix.
  hardening.geoBlock.sites = [
    "photos.qwt.ch"
    "jellyfin.qwt.ch"
    "jellyseerr.qwt.ch"
    "home.qwt.ch"
    "backup.qwt.ch"
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "evelyn@andrist.dev";

    # One wildcard certificate for all internal sites. The names resolve to
    # private addresses, so Let's Encrypt cannot reach them over HTTP; the
    # proof goes through a DNS record at Cloudflare instead.
    certs."internal.qwt.ch" = {
      domain = "*.internal.qwt.ch";
      dnsProvider = "cloudflare";
      credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" =
        config.sops.secrets."cloudflare/dns_api_token".path;
      group = config.services.nginx.group;
      # Before asking Let's Encrypt, lego waits until it can see the record
      # itself. Through the router's DNS that timed out (an old "no such
      # record" answer is kept for 30 minutes), so only ask Cloudflare's own
      # name servers.
      extraLegoFlags = [ "--dns.propagation.disable-rns" ];
    };
  };

  # Can edit DNS for all of qwt.ch, so it is kept out of secrets.yaml, which
  # every host can read.
  sops.secrets."cloudflare/dns_api_token".sopsFile = ../../secrets/internal.yaml;
}
