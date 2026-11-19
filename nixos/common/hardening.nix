# Protection for the hosts that are reachable from the internet.
#
# Not imported by default: only the servers import this file.
#
# Two parts:
# - a country block in nginx for the sites listed in `hardening.geoBlock`
# - fail2ban: repeated failed logins get the address blocked for a while
#
# ssh is deliberately not behind the country block, so a country can always
# be added from anywhere.
{ config, lib, pkgs, ... }:
let
  cfg = config.hardening.geoBlock;
  countries = lib.concatStringsSep "|" cfg.countries;
  geoBlockUsed = cfg.sites != [ ] || cfg.cloudflareSites != [ ];
  journalJail = { unit, failregex, maxretry ? 5 }: {
    filter.Definition = {
      inherit failregex;
      journalmatch = "_SYSTEMD_UNIT=${unit}";
    };
    settings = {
      backend = "systemd";
      port = "http,https";
      inherit maxretry;
      findtime = "10m";
    };
  };
in {
  options.hardening.geoBlock = {
    countries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "CH" "DE" ];
      description = ''
        Countries (ISO codes) that may reach the listed sites. Germany is in
        because nixserver is there and backs up to backup.qwt.ch.
      '';
    };
    sites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "nginx sites that visitors reach directly.";
    };
    cloudflareSites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        nginx sites behind Cloudflare's proxy. nginx only sees Cloudflare's
        address there, so the country comes from the CF-IPCountry header.
        Only for sites that accept nothing but Cloudflare's addresses,
        otherwise anyone can send that header themselves.
      '';
    };
  };

  config = {
    ###########################################################################
    #                              Country block                              #
    ###########################################################################

    services.nginx = lib.mkIf geoBlockUsed {
      additionalModules = [ pkgs.nginxModules.geoip2 ];

      # 1.30.7 fixes remote code execution over HTTP/2 (CVE-2026-123007,
      # CVE-2026-123633, CERT-EU 2026-022). nixos-unstable was still on
      # 1.30.6 on 2026-11-19. Remove this line once it has 1.30.7 or newer.
      package = pkgs.master.nginxStable;

      # The database comes from nixpkgs and gets newer with every flake
      # update, so there is no account and no download timer.
      commonHttpConfig = ''
        geoip2 ${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb {
          $geoip2_country_code country iso_code;
        }

        # LAN, VPN (arrives as the TrueNAS) and the host itself: these
        # addresses have no country.
        geo $geo_local {
          default        0;
          127.0.0.0/8    1;
          10.0.0.0/8     1;
          172.16.0.0/12  1;
          192.168.0.0/16 1;
          ::1            1;
          fc00::/7       1;
          fe80::/10      1;
        }

        # Let's Encrypt checks from all over the world; without this the
        # certificates could no longer be renewed.
        map $request_uri $geo_acme {
          default                          0;
          ~^/\.well-known/acme-challenge/  1;
        }

        map "$geo_acme$geo_local:$geoip2_country_code" $geo_blocked {
          default            1;
          ~^(1.|.1):         0;
          ~:(${countries})$  0;
        }

        map $http_cf_ipcountry $geo_blocked_cloudflare {
          default            1;
          ~^(${countries})$  0;
        }
      '';

      # 444: close the connection without an answer
      virtualHosts = lib.mkMerge [
        (lib.genAttrs cfg.sites (_: {
          extraConfig = "if ($geo_blocked) { return 444; }";
        }))
        (lib.genAttrs cfg.cloudflareSites (_: {
          extraConfig = "if ($geo_blocked_cloudflare) { return 444; }";
        }))
      ];
    };

    ###########################################################################
    #                                fail2ban                                 #
    ###########################################################################

    services.fail2ban = {
      enable = true;
      # Never the LAN: VPN clients all arrive as the TrueNAS, so one ban
      # there would lock out everyone on the VPN.
      ignoreIP = [ "192.168.1.0/24" ];
      maxretry = 5;
      bantime = "1h";
      # longer for addresses that come back, up to a week
      bantime-increment = {
        enable = true;
        maxtime = "168h";
      };

      # The sshd jail is on by default.
      jails = lib.mkMerge [
        # Failed logins of the apps behind nginx (Jellyfin, Immich,
        # Jellyseerr, roundcube, ...). Only POST: the apps' web pages get
        # 401/403 on ordinary page loads while nobody is logged in.
        (lib.mkIf config.services.nginx.enable {
          nginx-login = {
            filter.Definition.failregex =
              ''^<HOST> - \S+ \[[^\]]*\] "POST [^"]*" (?:401|403)\s'';
            settings = {
              backend = "auto";
              logpath = "/var/log/nginx/access.log";
              port = "http,https";
              maxretry = 10;
              findtime = "10m";
            };
          };
        })

        # These two answer a wrong password with a status that says nothing
        # (Home Assistant 200, Vaultwarden 400), but write it to their log.
        # fail2ban ships a "vaultwarden" filter for a log file; it does not
        # fit the journal, hence the other name.
        (lib.mkIf config.services.home-assistant.enable {
          home-assistant = journalJail {
            unit = "home-assistant.service";
            failregex = ''^.*Login attempt or request with invalid authentication from .*\(<ADDR>\).*$'';
          };
        })
        (lib.mkIf config.services.vaultwarden.enable {
          vaultwarden-login = journalJail {
            unit = "vaultwarden.service";
            failregex = ''^.*(?:Username or password is incorrect|Invalid TOTP code|Invalid admin token).* IP: <ADDR>'';
          };
        })

        # Mail logins (SMTP and IMAP). Only failed logins count, not
        # rejected mail, so other mail servers are never locked out.
        (lib.mkIf config.services.postfix.enable {
          postfix.settings = {
            mode = "auth";
            backend = "systemd";
          };
          dovecot.settings.backend = "systemd";
        })
      ];
    };

    # keep the bans and their history over a reboot
    environment.persistence."/persist".directories = [ "/var/lib/fail2ban" ];
  };
}
