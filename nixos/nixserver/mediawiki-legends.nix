{ config, lib, pkgs, ... }: {
 #  services.mediawiki = {
 #    enable = true;
 #    name = "Sample MediaWiki";
 #    httpd.virtualHost = {
 #      hostName = "legends.qwt.ch";
 #      adminAddr = "admin@example.com";
 #      listen = [
	# {
	#   ip = "127.0.0.1";
	#   port = 8203;
	#   ssl = false;
	# }
 #      ];
 #    };
 #    # Administrator account username is admin.
 #    # Set initial password to "cardbotnine" for the account admin.
 #    passwordFile = pkgs.writeText "password" "cardbotnine";
 #    extraConfig = ''
 #      # Disable anonymous editing
 #      $wgGroupPermissions['*']['edit'] = false;
 #    '';
	#
 #    extensions = {
 #      # some extensions are included and can enabled by passing null
 #      VisualEditor = null;
	#
 #      # https://www.mediawiki.org/wiki/Extension:TemplateStyles
 #      TemplateStyles = pkgs.fetchzip {
	# url = "https://extdist.wmflabs.org/dist/extensions/TemplateStyles-REL1_40-5c3234a.tar.gz";
	# hash = "sha256-IygCDgwJ+hZ1d39OXuJMrkaxPhVuxSkHy9bWU5NeM/E=";
 #      };
 #    };
 #  };

  systemd.services.init-mediawiki-network = {
    description = "Create the network bridge for MediaWiki.";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";
    script = let dockercli = "${config.virtualisation.docker.package}/bin/docker"; in ''
      # mediawiki-net network
      check=$(${dockercli} network ls | grep "mediawiki-net" || true)
      if [ -z "$check" ]; then
	${dockercli} network create mediawiki-net
      else
	echo "mediawiki-net already exists in docker"
      fi
    '';
  };

  virtualisation.oci-containers.containers = {
    mediawiki = {
      autoStart = true;
      image = "mediawiki:1.42.3";
      volumes = [
	"/persist/data/mediawiki/images:/var/www/html/images"
	"/persist/data/mediawiki/LocalSettings.php:/var/www/html/LocalSettings.php"
      ];
      ports = [ "127.0.0.1:8203:80" ];
      environment = {
	MYSQL_DATABASE = "mediawiki";
	MYSQL_USER = "mediawiki";
	MYSQL_PASSWORD = "mediawiki";
	MYSQL_RANDOM_ROOT_PASSWORD = "yes";
      };
      extraOptions = [ "--network=mediawiki-net" ];
    };

    mysql = {
      autoStart = true;
      image = "mysql";
      volumes = [
	"/persist/data/mediawiki/mysql:/var/lib/mysql"
      ];
      environment = {
	MYSQL_DATABASE = "mediawiki";
	MYSQL_USER = "mediawiki";
	MYSQL_PASSWORD = "mediawiki";
	MYSQL_RANDOM_ROOT_PASSWORD = "yes";
      };
      extraOptions = [ "--network=mediawiki-net" ];
    };
  };
}
