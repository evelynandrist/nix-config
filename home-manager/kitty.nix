{ config, lib, pkgs, ... }: {
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    shellIntegration.enableZshIntegration = true;
    settings = {
      disable_ligatures = "never";
      background_opacity = "0.5";
    };
  };
}
