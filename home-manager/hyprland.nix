{ config, lib, pkgs, ... }: {
  xdg.mimeApps.enable = true;

  home.packages = with pkgs; [
    bluetuith
    fira
    flashfocus
    grimblast
    gtk3
    htop-vim
    hyprland-autoname-workspaces
    imv
    mpvpaper
    rclone
    rsync
    slurp
    swaylock-effects
    wdisplays
    wl-clipboard
    wlsunset
    wofi
    wpgtk
  ];

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
    NIXOS_OZONE_WL = 1;
    QT_QPA_PLATFORM = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XCURSOR_SIZE = 32;
  };

  xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
      configPackages = [ pkgs.hyprland ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland.override { wrapRuntimeDeps = false; };
    xwayland.enable = true;
    systemd = {
      enable = true;
      # Same as default, but stop graphical-session too
      extraCommands = lib.mkBefore [
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };
    settings = {
      monitor = ",highres,auto,2";
      env = [
        "XCURSOR_SIZE,32"
        "GDK_SCALE,2"
      ];
      xwayland = {
        force_zero_scaling = true;
      };
      general = {
        gaps_in = 20;
        gaps_out = 30;
        border_size = 2;
        "col.active_border" = "rgba(${config.colorScheme.palette.base09}ff) rgba(${config.colorScheme.palette.base0D}ff) 45deg";
        "col.inactive_border" = "rgba(${config.colorScheme.palette.base01}aa)";
        layout = "dwindle";
        allow_tearing = false;
      };
      group = {
        "col.border_active" = "rgba(cf33ffee) rgba(1e00ffee) 45deg";
        "col.border_inactive" = "rgba(${config.colorScheme.palette.base01}aa)";
        "col.border_locked_active" = "rgba(cf33ffee) rgba(1e00ffee) 45deg";
        "col.border_locked_inactive" = "rgba(${config.colorScheme.palette.base01}aa)";
        groupbar = {
          enabled = false;
        };
      };
      input = {
        kb_layout = "us,ch";
        kb_options = "ctrl:nocaps,grp:rctrl_rshift_toggle";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = "yes";
        };
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };
      dwindle = {
        pseudotile = "yes"; # master switch for pseudotiling.
        preserve_split = "yes"; # you probably want this
      };
      master = {
        new_is_master = true;
      };
      gestures = {
        workspace_swipe = "off";
      };
      misc = {
        force_default_wallpaper = 0; # Set to 0 to disable the anime mascot wallpapers
      };
      windowrulev2 = "nomaximizerequest, class:.*"; # You'll probably like this.
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 2;
        };
        drop_shadow = "yes";
        shadow_range = 20;
        shadow_render_power = 4;
        "col.shadow" = "rgba(1a1a1aee)";
      };
      animations = {
        enabled = "yes";
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      "exec-once" = [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "systemctl --user start hyprland-autoname-workspaces.service"
        "/usr/bin/emacs --daemon"
        "wl-paste --watch cliphist store"
      ];
      exec = [
        "killall waybar; waybar &"
        "~/video-paper.sh --restart"
      ];
      blurls = "waybar";
      "$mod" = "SUPER";
      "$reset_submap" = "hyprctl dispatch submap reset";
      bind = let
        terminal = "kitty";
        menu = "wofi --normal-window --show drun --terminal kitty --allow-images --lines 10";
        editor = "emacsclient -c -a \"emacs\"";
        browser = "firefox";
        fileManager = "dolphin";
      in [
        "$mod, return, exec, ${terminal}"
        "$mod, Q, killactive,"
        "$mod, M, exit, "
        "$mod, E, exec, ${fileManager}"
        "$mod SHIFT, space, togglefloating, "
        "$mod, D, exec, ${menu}"
        "$mod, P, pseudo, "
        "$mod, T, togglesplit, "
        "$mod, I, exec, ${editor}"
        "$mod, O, exec, ${browser}"
        "$mod SHIFT, C, exec, hyprctl reload"
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"
        "$mod, N, workspace, empty"
        "$mod SHIFT, N, movetoworkspace, empty"
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"
        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"
        "$mod SHIFT, p, exec, cliphist list | wofi --show dmenu --normal-window --lines 14 --style ~/.config/wpg/templates/wofi | cliphist decode | wl-copy"
      ] ++
      (
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
      binde = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessDown, exec, brightnessctl s 10%-"
        ", XF86MonBrightnessUp, exec, brightnessctl s +10%"
      ];
    };
    # This is order sensitive, so it has to come here.
    extraConfig = let
      color1 = config.colorScheme.palette.base01;
      color2 = config.colorScheme.palette.base02;
      color5 = config.colorScheme.palette.base05;
      color6 = config.colorScheme.palette.base06;
      color7 = config.colorScheme.palette.base07;
      color10 = config.colorScheme.palette.base0A;
      color11 = config.colorScheme.palette.base0B;
      color13 = config.colorScheme.palette.base0D;
    in ''
      $submap_resize = <span foreground='##${color10}'>󰩨</span>  <span foreground='##${color5}'><b>Resize</b></span> <span foreground='##${color10}'>(<b>↑ ↓ ← →</b>)</span>
      bind=$mod,r,submap,$submap_resize
      submap=$submap_resize
      binde=,l,resizeactive,15 0
      binde=,h,resizeactive,-15 0
      binde=,k,resizeactive,0 -15
      binde=,j,resizeactive,0 15
      bind=,escape,submap,reset
      submap=reset
      $submap_shutdown = <span foreground='##${color10}'></span>  <span foreground='##${color5}'>  <span foreground='##${color10}'>(<b>h</b>)</span>hibernate <span foreground='##${color10}'>(<b>l</b>)</span>lock <span foreground='##${color10}'>(<b>e</b>)</span>logout <span foreground='##${color10}'>(<b>r</b>)</span>reboot <span foreground='##${color10}'>(<b>u</b>)</span>suspend <span foreground='##${color10}'>(<b>s</b>)</span>shutdown </span>
      $purge_cliphist = rm -f $HOME/.cache/cliphist/db
      $locking = swaylock --daemonize --color \"##${color1}\" --inside-color \"##${color1}\" --inside-clear-color \"##${color6}\" --ring-color \"##${color2}\" --ring-clear-color \"##${color11}\" --ring-ver-color \"##${color13}\" --show-failed-attempts --fade-in 0.2 --grace 2 --effect-vignette 0.5:0.5 --effect-blur 7x5 --ignore-empty-password --screenshots --clock
      bind=$mod SHIFT,e,submap,$submap_shutdown
      submap=$submap_shutdown
      bind=,l,exec,$reset_submap && $locking # lock
      bind=,e,exec,$reset_submap && $purge_cliphist; loginctl terminate-user $USER # logout
      bind=,u,exec,$reset_submap && systemctl suspend # suspend
      bind=,h,exec,$reset_submap && systemctl hibernate # hibernate
      bind=,s,exec,$reset_submap && $purge_cliphist; systemctl poweroff # shutdown
      bind=,r,exec,$reset_submap && $purge_cliphist; systemctl reboot # reboot
      bind=,escape,submap,reset
      submap=reset
      $submap_screenshot = <span foreground='##${color10}'></span>  <span foreground='##${color5}'><b>Area</b></span> <span foreground='##${color10}'>(<b>a</b>)</span> <span foreground='##${color5}'><b>Screen</b></span> <span foreground='##${color10}'>(<b>s</b>)</span> <span foreground='##${color7}'>+ <span foreground='##${color10}'><b>Shift</b></span> for 󰆓</span>
      bind=,print,submap,$submap_screenshot
      submap=$submap_screenshot
      bind=,a,exec,$reset_submap && grimblast copy area
      bind=,s,exec,$reset_submap && grimblast copy screen
      bind=SHIFT,a,exec,$reset_submap && grimblast save area
      bind=SHIFT,s,exec,$reset_submap && grimblast save screen
      bind=,escape,submap,reset
      submap=reset
    '';
  };
}
