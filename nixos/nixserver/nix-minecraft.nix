{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    dataDir = "/persist/data/minecraft-servers";

    servers = {
      "TheTransAgenda" = {
	enable = false;
	package = pkgs.fabricServers.fabric;
	openFirewall = true;

	serverProperties = {
	  server-port = 43000;
	  difficulty = 1; # easy
	  gamemode = 0; # survival
	  max-players = 5;
	  level-name = "TheTransAgenda";
	  motd = "BURN DOWN THE CIS-TEM!";
	  view-distance = 16;
	};

	whitelist = {
	  eeeeeeeevelyn = "ac788709-ece6-43f0-b8ff-403c942453c5";
	  CreeperCraepe = "c47d0443-3a06-440e-af56-890943927ec8";
	};

	symlinks = {
	  # "mods" = ./mc-mods;
	};
      };
      "TheGayAgenda" = {
	enable = true;
	package = pkgs.fabricServers.fabric;
	openFirewall = true;

	serverProperties = {
	  server-port = 43000;
	  difficulty = 1; # easy
	  gamemode = 0; # survival
	  max-players = 5;
	  level-name = "TheGayAgenda";
	  motd = "BURN DOWN THE CIS-TEM!";
	  view-distance = 16;
	  resource-pack = "https://p-lux4.pcloud.com/D4Zm2lRvrZQROGSW7ZZZ8AV4VkZ2ZZ69JZkZbcgZMRZtYZL4ZDhqh5ZAn3pICDew34RTmcIAhi1Y7pCW3BV/toomuchtime.zip";
	  resource-pack-sha1 = "9078b851d708f89570054e3d7e0bd16a90569c40";
	  resource-pack-required = true;
	};

	whitelist = {
	  eeeeeeeevelyn = "ac788709-ece6-43f0-b8ff-403c942453c5";
	};

	symlinks = {
	  "mods" = ./mc-mods;
	  "TheGayAgenda/datapacks" = ./mc-datapacks;
	};

	files = {
	  "allowed_symlinks.txt" = {
	    value = [ "[regex].*" ];
	  };
	  "config/Geyser-Fabric/packs/toomuchtime.zip" = ./toomuchtime_bedrock.zip;
	};
      };
    };
  };
}
