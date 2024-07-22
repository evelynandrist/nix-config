{ config, lib, pkgs, ... }: {
  imports = [
    ./autoname-workspaces.nix
    # currently broken https://github.com/NixOS/nixpkgs/issues/326048
    # ./vimiv.nix
  ];

  xdg.mimeApps.enable = true;

  home.packages = with pkgs; [
    bluetuith
    brightnessctl
    cliphist
    fira
    flashfocus
    grimblast
    gtk3
    mpvpaper
    pcmanfm
    slurp
    wdisplays
    wl-clipboard
    wlsunset
    wofi
    wpgtk
  ];

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
	disable_loading_bar = true;
	hide_cursor = true;
	no_fade_in = false;
	no_fade_out = false;
      };

      background = [
	{
	  path = "screenshot";
	  blur_passes = 3;
	  blur_size = 8;
	}
      ];

      input-field = [
      {
	monitor = "";
	size = "200, 50";
	bothlock_color = -1;
	capslock_color = -1;
	check_color = "rgb(204, 136, 34)";
	dots_center = true;
	dots_rounding = -1;
	dots_size = 0.330000;
	dots_spacing = 0.150000;
	fade_on_empty = false;
	fade_timeout = 2000;
	fail_color = "rgb(204, 34, 34)";
	fail_text = "<i>$FAIL</i>";
	fail_transition = 300;
	font_color = "rgb(202, 211, 245)";
	halign = "center";
	hide_input = false;
	inner_color = "rgb(91, 96, 120)";
	invert_numlock = false;
	numlock_color = -1;
	outer_color = "rgb(24, 25, 38)";
	outline_thickness = 5;
	placeholder_text = "<span foreground=\"##cad3f5\">Password...</span>";
	position = "0, -80";
	rounding = -1;
	swap_font_color = false;
	valign = "center";
      }
      ];

      label = [
      {
	monitor = "";
	color = "rgb(202, 211, 245)";
	font_family = "JetBrainsMono Nerd Font";
	font_size = 100;
	halign = "center";
	position = "0, 330";
	text = "<span font_weight=\"ultrabold\">$TIME</span>";
	valign = "center";
      }
      {
	monitor = "";
	color = "rgb(202, 211, 245)";
	font_family = "JetBrainsMono Nerd Font";
	font_size = 50;
	halign = "center";
	position = "15, -350";
	text = "<span font_weight=\"ultrabold\">󰌾 </span>";
	valign = "center";

      }
      {
	monitor = "";
	color = "rgb(202, 211, 245)";
	font_family = "JetBrainsMono Nerd Font";
	font_size = "25";
	halign = "center";
	position = "0, 45";
	text = "<span font_weight=\"semibold\">Hi there, $USER!</span>";
	valign = "center";

      }
      {
	monitor = "";
	color = "rgb(202, 211, 245)";
	font_family = "JetBrainsMono Nerd Font";
	font_size = 25;
	halign = "center";
	position = "0, -430";
	text = "<span font_weight=\"bold\">Locked</span>";
	valign = "center";
      }
      {
	monitor = "";
	color = "rgb(202, 211, 245)";
	font_family = "JetBrainsMono Nerd Font";
	font_size = 30;
	halign = "center";
	position = "0, 210";
	text = "cmd[update:120000] echo \"<span font_weight='bold'>$(date +'%a %d %B')</span>\"";
	valign = "center";
      }
      {
	monitor = "";
	color = "rgb(202, 211, 245)";
	font_family = "JetBrainsMono Nerd Font";
	font_size = 25;
	halign = "right";
	position = "5, 8";
	text = "<span font_weight=\"ultrabold\"> </span>";
	valign = "bottom";
      }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
	after_sleep_cmd = "hyprctl dispatch dpms on";
	ignore_dbus_inhibit = false;
	lock_cmd = "hyprlock";
      };

      listener = [
      { # lock after 15 minutes
	timeout = 900;
	on-timeout = "hyprlock";
      }
      {
	timeout = 1200; # turn off screen after 20 minutes
	on-timeout = "hyprctl dispatch dpms off";
	on-resume = "hyprctl dispatch dpms on";
      }
      ];
    };
  };

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
    NIXOS_OZONE_WL = 1;
    QT_QPA_PLATFORM = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XCURSOR_SIZE = 128;
  };

  xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
      configPackages = [ config.wayland.windowManager.hyprland.package ];
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
      monitor = ",highres,auto,auto";
      env = [
        "XCURSOR_SIZE,128"
        "GDK_SCALE,2"
      ];
      xwayland = {
        force_zero_scaling = true;
      };
      general = {
        gaps_in = 20;
        gaps_out = 30;
        border_size = 2;
        "col.active_border" = "rgba(${config.colorScheme.palette.base09}ff) rgba(${config.colorScheme.palette.base0A}ff) 45deg";
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
        new_status = "master";
      };
      gestures = {
        workspace_swipe = "off";
      };
      misc = {
        force_default_wallpaper = 0; # Set to 0 to disable the anime mascot wallpapers
      };
      windowrulev2 = [
	"suppressevent maximize, class:.*" # You'll probably like this.
	"float, title:^(Picture-in-Picture)$"
	"pin, title:^(Picture-in-Picture)$"
      ];
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
        "zsh -c \"emacs --daemon\""
        "wl-paste --watch cliphist store"
      ];
      exec = [
        "pkill waybar; waybar &"
        "hyprland-autoname-workspaces"
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
        fileManager = "pcmanfm";
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
        "$mod, A, togglespecialworkspace, magic2"
        "$mod SHIFT, A, movetoworkspace, special:magic2"
        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"
        "$mod SHIFT, p, exec, cliphist list | wofi --show dmenu --normal-window --lines 14 | cliphist decode | wl-copy"
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
      bindm = [
	"$mod, mouse:272, movewindow" # move window with mouse
	"$mod SHIFT, mouse:272, resizewindow" # resize window with mouse
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
      $submap_shutdown = <span foreground='##${color10}'></span>  <span foreground='##${color5}'>  <span foreground='##${color10}'>(<b>h</b>)</span>hibernate   <span foreground='##${color10}'>(<b>l</b>)</span>lock   <span foreground='##${color10}'>(<b>e</b>)</span>logout   <span foreground='##${color10}'>(<b>r</b>)</span>reboot   <span foreground='##${color10}'>(<b>u</b>)</span>suspend   <span foreground='##${color10}'>(<b>s</b>)</span>shutdown   </span>
      $purge_cliphist = rm -f $HOME/.cache/cliphist/db
      $locking = hyprlock
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
      $submap_screenshot = <span foreground='##${color10}'>󰄄</span>  <span foreground='##${color5}'><b>Area</b></span> <span foreground='##${color10}'>(<b>a</b>)</span>   <span foreground='##${color5}'><b>Screen</b></span> <span foreground='##${color10}'>(<b>s</b>)</span>   <span foreground='##${color7}'>+   <span foreground='##${color10}'><b>Shift</b></span>  for  󰆓</span>
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
