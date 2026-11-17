{ config, lib, pkgs, ... }:
let
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";

  # eDP-1 is a Samsung AMOLED (ATNA60YV04-0). It has no backlight: dimming it drives
  # the emitters with PWM, which flickers hard enough to be visible in slow motion and
  # to cause headaches. So the panel stays pinned at 100% and dimming happens in the
  # GPU's colour LUT instead, which is flicker-free. On OLED this still saves power,
  # because emission scales with pixel value.
  # State is kept here rather than read back from hyprsunset: it reports gamma as a
  # drifting float (60.000004, then 7.6e-06 near zero) which shell arithmetic cannot
  # consume, and reading-then-writing races against key repeat. Always set an absolute
  # value from our own integer instead.
  oled-brightness = pkgs.writeShellScriptBin "oled-brightness" ''
    state="''${XDG_RUNTIME_DIR:-/tmp}/oled-brightness"
    step=10
    cur="$(cat "$state" 2>/dev/null || echo 100)"
    case "$1" in
      up)     new=$(( cur + step )) ;;
      down)   new=$(( cur - step )) ;;
      set)    new="''${2:-100}" ;;
      get)    echo "$cur"; exit 0 ;;
      waybar) printf '{"text":"%s","percentage":%s,"tooltip":"display gamma %s%%"}\n' "$cur" "$cur" "$cur"; exit 0 ;;
      *)      echo "usage: oled-brightness up|down|set <n>|get|waybar" >&2; exit 1 ;;
    esac
    # 100 is the panel's native output. hyprsunset will go all the way to 0 (a black
    # screen) if asked, so the lower clamp is load-bearing.
    [ "$new" -gt 100 ] && new=100
    [ "$new" -lt 10 ] && new=10
    printf '%s' "$new" > "$state"
    ${hyprctl} hyprsunset gamma "$new" >/dev/null
    ${pkgs.procps}/bin/pkill -RTMIN+9 waybar 2>/dev/null || true
  '';
  # Pango markup for the submap indicator. waybar's hyprland/submap module
  # displays the submap's name, so the label *is* the name — see
  # modules/keymap/hyprland.nix.
  # hyprctl dispatch takes a Lua dispatcher expression since Hyprland 0.55.
  dpms = action: "hyprctl dispatch 'hl.dsp.dpms({ action = \"${action}\" })'";
  # (Re)start waybar. Serialised with flock because the start and reload
  # events can fire close together; -o keeps waybar from inheriting the lock.
  restartBar = "${pkgs.util-linux}/bin/flock -o \"$XDG_RUNTIME_DIR/waybar-restart.lock\" sh -c 'pkill waybar; waybar &'";
  lua = lib.generators.mkLuaInline;
  exec = cmd: lua "hl.dsp.exec_cmd(${lib.generators.toLua { } cmd})";
  # Lua text: run shell commands when an event fires.
  onEvent = event: cmds:
    "hl.on(${lib.generators.toLua { } event}, function()\n"
    + lib.concatMapStrings (c: "  hl.exec_cmd(${lib.generators.toLua { } c})\n") cmds
    + "end)\n";
  color5 = config.colorScheme.palette.base05;
  color7 = config.colorScheme.palette.base07;
  color10 = config.colorScheme.palette.base0A;
in {
  imports = [
    ./vimiv.nix

    ../common/keymap.nix
    ../../modules/keymap/hyprland.nix
  ];

  keymap.apps = {
    terminal = "kitty";
    menu = "wofi --normal-window --show drun --terminal kitty --allow-images --lines 10";
    editor = "emacsclient -c -a \"emacs\"";
    browser = "zen-beta";
    fileManager = "pcmanfm";
  };

  keymap.modes = {
    resize.hyprland.label = "<span foreground='#${color10}'>󰩨</span>  <span foreground='#${color5}'><b>Resize</b></span> <span foreground='#${color10}'>(<b>↑ ↓ ← →</b>)</span>";

    shutdown.hyprland = {
      label = "<span foreground='#${color10}'></span>  <span foreground='#${color5}'>  <span foreground='#${color10}'>(<b>h</b>)</span>hibernate   <span foreground='#${color10}'>(<b>l</b>)</span>lock   <span foreground='#${color10}'>(<b>e</b>)</span>logout   <span foreground='#${color10}'>(<b>r</b>)</span>reboot   <span foreground='#${color10}'>(<b>u</b>)</span>suspend   <span foreground='#${color10}'>(<b>s</b>)</span>shutdown   </span>";
      resetOnDispatch = true;
    };

    screenshot.hyprland = {
      label = "<span foreground='#${color10}'>󰄄</span>  <span foreground='#${color5}'><b>Area</b></span> <span foreground='#${color10}'>(<b>a</b>)</span>   <span foreground='#${color5}'><b>Screen</b></span> <span foreground='#${color10}'>(<b>s</b>)</span>   <span foreground='#${color7}'>+   <span foreground='#${color10}'><b>Shift</b></span>  for  󰆓</span>";
      resetOnDispatch = true;
    };
  };

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
    oled-brightness
    pcmanfm
    slurp
    wdisplays
    wl-clipboard
    wlsunset
    wofi
    wpgtk
  ];

  services.hyprsunset = {
    enable = true;
    # Only here to dim via gamma, not to shift colour. hyprsunset defaults to 6000K,
    # which would warm the display as a side effect, so pin it to the D65 white point.
    # Gamma and temperature are independent, so this leaves dimming untouched.
    extraArgs = [ "--temperature" "6500" ];
  };

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
	after_sleep_cmd = dpms "enable";
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
	on-timeout = dpms "disable";
	on-resume = dpms "enable";
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
      # hyprland already includes xdg-desktop-portal-hyprland
      extraPortals = [
	pkgs.xdg-desktop-portal-gtk
      ];
      configPackages = [ config.wayland.windowManager.hyprland.package ];
  };

  # Hyprland writes an example hyprland.lua whenever it starts without one
  # (which happened on the first boot after the Lua migration). Replace such a
  # file instead of failing the activation on it.
  xdg.configFile."hypr/hyprland.lua".force = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
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
    # Autostart. In extraConfig rather than `settings.on` so it is registered
    # after home-manager's own start hook, which resets graphical-session.target.
    extraConfig = lib.mkBefore (
      onEvent "hyprland.start" [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "zsh -c \"emacs --daemon\""
        "wl-paste --watch cliphist store"
        # The panel must sit at full output for PWM to be off; dimming is gamma-side.
        "${pkgs.brightnessctl}/bin/brightnessctl set 100%"
        restartBar
      ]
      # Also after every config reload, like hyprlang's `exec`.
      + onEvent "config.reloaded" [
        restartBar
      ]
    );
    # Lua config: each attribute is an `hl.<name>(...)` call, lists are one
    # call per element. Key binds and submaps come from the shared keymap via
    # modules/keymap/hyprland.nix (extraConfig).
    settings = {
      monitor = [
        { output = "DP-1"; mode = "2560x1440@74.97"; position = "0x0"; scale = 1.25; }
        { output = "eDP-1"; mode = "3840x2400@60.00"; position = "256x1152"; scale = 2.5; }
        { output = ""; mode = "highres"; position = "auto"; scale = 2.5; }
      ];
      env = [
        { _args = [ "XCURSOR_SIZE" "128" ]; }
        { _args = [ "GDK_SCALE" "2" ]; }
      ];
      config = {
        xwayland = {
          force_zero_scaling = true;
        };
        general = {
          gaps_in = 20;
          gaps_out = 30;
          border_size = 2;
          col = {
            active_border = {
              colors = [
                "rgba(${config.colorScheme.palette.base09}ff)"
                "rgba(${config.colorScheme.palette.base0A}ff)"
              ];
              angle = 45;
            };
            inactive_border = "rgba(${config.colorScheme.palette.base01}aa)";
          };
          layout = "dwindle";
          allow_tearing = false;
        };
        group = {
          col = {
            border_active = { colors = [ "rgba(cf33ffee)" "rgba(1e00ffee)" ]; angle = 45; };
            border_inactive = "rgba(${config.colorScheme.palette.base01}aa)";
            border_locked_active = { colors = [ "rgba(cf33ffee)" "rgba(1e00ffee)" ]; angle = 45; };
            border_locked_inactive = "rgba(${config.colorScheme.palette.base01}aa)";
          };
          groupbar = {
            enabled = false;
          };
        };
        input = {
          kb_layout = "us,ch";
          kb_options = "ctrl:nocaps,grp:rctrl_rshift_toggle";
          follow_mouse = 1;
          touchpad = {
            natural_scroll = true;
          };
          sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
        };
        dwindle = {
          preserve_split = true; # you probably want this
        };
        master = {
          new_status = "master";
        };
        misc = {
          force_default_wallpaper = 0; # Set to 0 to disable the anime mascot wallpapers
        };
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 2;
          };
          shadow = {
            enabled = true;
            range = 15;
            render_power = 4;
            color = "rgba(1a1a1acc)";
          };
        };
        animations = {
          enabled = true;
        };
      };
      window_rule = [
        { match.class = ".*"; suppress_event = "maximize"; } # You'll probably like this.
        { match.title = "^(Picture-in-Picture)$"; float = true; pin = true; }
        # Maximised windows (mod+F) look like a lone tiled window otherwise.
        { match.fullscreen_state_internal = 1; border_color = "rgb(${config.colorScheme.palette.base0F})"; }
      ];
      layer_rule = [
        { match.namespace = "waybar"; blur = true; }
      ];
      curve = [
        { _args = [ "myBezier" { type = "bezier"; points = [ [ 0.05 0.9 ] [ 0.1 1.05 ] ]; } ]; }
      ];
      animation = [
        { leaf = "windows"; enabled = true; speed = 7; bezier = "myBezier"; }
        { leaf = "windowsOut"; enabled = true; speed = 7; bezier = "default"; style = "popin 80%"; }
        { leaf = "border"; enabled = true; speed = 10; bezier = "default"; }
        { leaf = "borderangle"; enabled = true; speed = 8; bezier = "default"; }
        { leaf = "fade"; enabled = true; speed = 7; bezier = "default"; }
        { leaf = "workspaces"; enabled = true; speed = 6; bezier = "default"; }
      ];
      # What stays here is what has no AeroSpace counterpart and is
      # deliberately Hyprland-only.
      bind = [
        { _args = [ "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") { repeating = true; } ]; }
        { _args = [ "XF86AudioMicMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") { repeating = true; } ]; }
        { _args = [ "XF86AudioRaiseVolume" (exec "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+") { repeating = true; } ]; }
        { _args = [ "XF86AudioLowerVolume" (exec "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-") { repeating = true; } ]; }
        # Gamma, not backlight — see the oled-brightness comment above.
        { _args = [ "XF86MonBrightnessDown" (exec "oled-brightness down") { repeating = true; } ]; }
        { _args = [ "XF86MonBrightnessUp" (exec "oled-brightness up") { repeating = true; } ]; }
        # move / resize window with the mouse
        { _args = [ "${config.keymap.mod} + mouse:272" (lua "hl.dsp.window.drag()") { mouse = true; } ]; }
        { _args = [ "${config.keymap.mod} + SHIFT + mouse:272" (lua "hl.dsp.window.resize()") { mouse = true; } ]; }
      ];
    };
  };
}
