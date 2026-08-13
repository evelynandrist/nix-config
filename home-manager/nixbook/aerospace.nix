{ config, lib, pkgs, ... }: {
  imports = [
    ../common/keymap.nix
    ../../modules/keymap/aerospace.nix
  ];

  keymap.apps = {
    terminal = "${pkgs.kitty}/bin/kitty --single-instance";
    fileManager = "/usr/bin/open -a Finder";
    browser = "/usr/bin/open -a Safari";
    # Spotlight (Cmd+Space, reachable through Deskflow's Ctrl->Cmd mapping)
    # already covers this, and there is no emacs on the Mac.
    menu = null;
    editor = null;
  };

  programs.aerospace = {
    enable = true;
    launchd.enable = true;

    settings = {
      # try to match hyprland
      gaps = {
        inner.horizontal = 20;
        inner.vertical = 20;
        outer.left = 30;
        outer.right = 30;
        outer.top = 30;
        outer.bottom = 30;
      };

      # try to somewhat match hyprland's dwindle behavior
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      # Deskflow forwards Ctrl as Cmd, so Cmd+Tab still reaches macOS app
      # switching; keep AeroSpace out of the way of it.
      "on-focus-changed" = [ "move-mouse window-lazy-center" ];
    };
  };
}
