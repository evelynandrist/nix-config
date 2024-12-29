{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers = {
      "TheTransAgenda" = {
	enable = true;
	package = pkgs.fabricServers.fabric;
	openFirewall = true;

	serverProperties = {
	  server-port = 43000;
	  difficulty = 0; # peaceful
	  gamemode = 0; # survival
	  max-players = 5;
	  level-name = "TheTransAgenda";
	  motd = "BURN DOWN THE CIS-TEM!";
	};

	whitelist = {
	  eeeeeeeevelyn = "ac788709-ece6-43f0-b8ff-403c942453c5";
	  CreeperCraepe = "c47d0443-3a06-440e-af56-890943927ec8";
	};
      };
    };
  };
}
