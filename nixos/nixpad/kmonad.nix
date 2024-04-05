{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.kmonad.nixosModules.default ];
  
  services.kmonad = {
    enable = true;
    keyboards = {
      laptop_keyboard = {
	device = "/dev/input/by-path/platform-i8042-serio-0-event-kbd";
	config = builtins.readFile ./kmonad.kbd;
      };
    };
  };
}
