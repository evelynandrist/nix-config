{ config, lib, pkgs, ... }: {
  xdg.mimeApps.enable = true;

  home.packages = with pkgs; [
    bluetuith
    fira
    fira-code-nerdfont
    flashfocus
    grimblast
    gtk3
    htop-vim
    hyprland-autoname-workspaces
    imv
    mpvpaper
    nerdfonts
    rclone
    rsync
    slurp
    swaylock-effects
    waybar
    wdisplays
    wl-clipboard
    wlsunset
    wofi
    wpgtk
    xwayland
  ];

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
    QT_QPA_PLATFORM = "wayland";
  };

  xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
      configPackages = [ pkgs.hyprland ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland.override { wrapRuntimeDeps = false; };
    systemd = {
      enable = true;
      # Same as default, but stop graphical-session too
      extraCommands = lib.mkBefore [
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };
    settings = {
      "$mod" = "SUPER";
      bind =
        [
          "$mod, F, exec, firefox"
          ", Print, exec, grimblast copy area"
        ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
          builtins.concatLists (builtins.genList (
            x: let
              ws = let
                c = (x + 1) / 10;
              in
                builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, workspace, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          )
            10)
        );
    };
  };
}
