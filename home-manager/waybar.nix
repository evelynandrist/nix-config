{ config, lib, pkgs, ... }: {
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        height = 30;
        position = "top";
        margin = "10";
        modules-left = [ "custom/menu" "hyprland/workspaces" ];
        modules-center = [ "custom/wf-recorder" "hyprland/submap" ];
        modules-right = [
          # informational
          "hyprland/language"
          "custom/github"
          "cpu"
          "memory"
          "battery"
          "temperature"

          # connecting
          "network"
          "bluetooth"

          # media
          "custom/playerctl"
          "idle_inhibitor"
          "custom/dnd"
          "pulseaudio"
          "backlight"

          # system
          "custom/sunset"

          "tray"
          "clock"
        ];

        # Modules

        battery = {
          interval = 30;
          states = {
            warning = 30;
            critical = 15;
          };
          format-charging = "󰂄 {capacity}%";
          format = "{icon} {capacity}%";
          format-icons = [ "󱃍" "󰁺" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip = true;
        };

        clock = {
          interval = 60;
          format = "{:%e %b %Y %H:%M}";
          tooltip = true;
          tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
          on-click = "hyprctl dispatch exec [floating] \\$calendar";
        };

        cpu = {
          interval = 5;
          format = "󰘚 {usage}%";
          states = {
            warning = 70;
            critical = 90;
          };
          on-click = "hyprctl dispatch exec [floating] kitty 'sh -c \"$HOME/.config/color-sequences.sh & htop\"'";
        };

        memory = {
          interval = 5;
          format = "󰍛 {}%";
          states = {
            warning = 70;
            critical = 90;
          };
          on-click = "hyprctl dispatch exec [floating] kitty 'sh -c \"$HOME/.config/color-sequences.sh & htop\"'";
        };

        network = {
          interval = 5;
          format-wifi = " ";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          tooltip-format = "{ifname} ({essid}): {ipaddr}";
          on-click = "hyprctl dispatch exec [floating] kitty 'sh -c \"$HOME/.config/color-sequences.sh & nmtui\"'";
        };

        "hyprland/submap" = {
          format = "<span style=\"italic\">{}</span>";
          tooltip = false;
        };

        "hyprland/workspaces" = {
          format = "{name}";
          sort-by-number = true;
          active-only = false;
          on-click = "activate";
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            activated = "󰒳";
            deactivated = "󰒲";
          };
          tooltip = true;
          tooltip-format-activated = "power-saving disabled";
          tooltip-format-deactivated = "power-saving enabled";
        };

        backlight = {
          format = "{icon} {percent}%";
          format-icons = [ "󰃞" "󰃟" "󰃠" ];
          on-scroll-up = "hyprctl dispatch exec brightnessctl s +10%";
          on-scroll-down = "hyprctl dispatch exec brightnessctl s 10%-";
        };

        pulseaudio = {
          scroll-step = 5;
          format = "{icon} {volume}%{format_source}";
          format-muted = "󰖁 {format_source}";
          format-source = "";
          format-source-muted = " 󰍭";
          format-icons = {
            headphone = "󰋋";
            headset = "󰋎";
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          tooltip-format = "{icon} {volume}% {format_source}";
          on-click = "hyprctl dispatch exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-scroll-up = "hyprctl dispatch exec \"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+\"";
          on-scroll-down = "hyprctl dispatch exec \"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-\"";
        };

        temperature = {
          hwmon-path = "/sys/class/hwmon/hwmon5/temp1_input";
          critical-threshold = 90;
          interval = 5;
          format = "{icon} {temperatureC}°";
          format-icons = [ "" "" "" ];
          tooltip = false;
          on-click = "hyprctl dispatch exec [floating] kitty 'sh -c \"$HOME/.config/color-sequences.sh & watch sensors\"'";
        };

        tray = {
          icon-size = 21;
          spacing = 5;
        };

        "custom/menu" = {
          format = "";
          on-click = "hyprctl dispatch exec [floating] \\$menu";
          tooltip = false;
        };

        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          on-click = "hyprctl dispatch exec [floating] kitty 'sh -c \"$HOME/.config/color-sequences.sh & bluetuith\"'";
          on-click-right = "rfkill toggle bluetooth";
          tooltip-format = "{}";
        };

        "hyprland/language" = {
          format = " {}";
          min-length = 5;
          tooltip = false;
        };

        "custom/sunset" = {
          interval = "once";
          tooltip = true;
          return-type = "json";
          format = "{icon}";
          format-icons = {
            on = "󰌵";
            off = "󰌶";
          };
          exec = "fallback_latitude=50.1 fallback_longitude=8.7 latitude= longitude= $HOME/.config/hypr/scripts/sunset.sh";
          on-click = "$HOME/.config/hypr/scripts/sunset.sh toggle; pkill -RTMIN+6 waybar";
          exec-if = "$HOME/.config/hypr/scripts/sunset.sh check";
          signal = 6;
        };

        "custom/wf-recorder" = {
          interval = "once";
          return-type = "json";
          format = "{}";
          tooltip-format = "{tooltip}";
          exec = "echo '{\"class\": \"recording\",\"text\":\"󰑊\",\"tooltip\":\"press $mod+Esc to stop recording\"}'";
          exec-if = "pgrep wf-recorder";
          on-click = "killall -s SIGINT wf-recorder";
          signal = 8;
        };

        "custom/github" = {
          interval = 300;
          tooltip = false;
          return-type = "json";
          format = " {}";
          exec = "gh api '/notifications' -q '{ text: length }' | cat -";
          exec-if = "[ -x \"$(command -v gh)\" ] && gh auth status 2>&1 | grep -q -m 1 'Logged in' && gh api '/notifications' -q 'length' | grep -q -m 1 '0' ; test $? -eq 1";
          on-click = "xdg-open https://github.com/notifications && sleep 30 && pkill -RTMIN+4 waybar";
          signal = 4;
        };

        "custom/playerctl" = {
          interval = "once";
          tooltip = true;
          return-type = "json";
          format = "{icon}";
          format-icons = {
            Playing = "󰏦";
            Paused = "󰐍";
          };
          exec = "playerctl metadata --format '{\"alt\": \"{{status}}\", \"tooltip\": \"{{playerName}}:  {{markup_escape(title)}} - {{markup_escape(artist)}}\" }'";
          on-click = "playerctl play-pause; pkill -RTMIN+5 waybar";
          on-click-right = "playerctl next; pkill -RTMIN+5 waybar";
          on-scroll-up = "playerctl position 10+; pkill -RTMIN+5 waybar";
          on-scroll-down = "playerctl position 10-; pkill -RTMIN+5 waybar";
          signal = 5;
        };

        "custom/dnd" = {
          interval = "once";
          return-type = "json";
          format = "{}{icon}";
          format-icons = {
            default = "󰚢";
            dnd = "󰚣";
          };
          on-click = "makoctl mode | grep 'do-not-disturb' && makoctl mode -r do-not-disturb || makoctl mode -a do-not-disturb; pkill -RTMIN+11 waybar";
          on-click-right = "makoctl restore";
          exec = "printf '{\"alt\":\"%s\",\"tooltip\":\"mode: %s\"}' $(makoctl mode | grep -q 'do-not-disturb' && echo dnd || echo default) $(makoctl mode | tail -1)";
          signal = 11;
        };
      };
    };
    style = let
      color0 = "#${config.colorScheme.palette.base00}";
      color1 = "#${config.colorScheme.palette.base01}";
      color15 = "#${config.colorScheme.palette.base0F}";
      active = "#${config.colorScheme.palette.base09}";
    in ''
/* Default color scheme */
@define-color bg_color ${color0};
@define-color fg_color ${color15};
@define-color base_color ${color1};
@define-color text_color ${color15};
@define-color selected_bg_color ${active};
@define-color selected_fg_color ${color15};
@define-color tooltip_bg_color ${color0};
@define-color tooltip_fg_color ${color15};

/* colormap actually used by the theme, to be overridden in other css files */
@define-color theme_bg_color @bg_color;
@define-color theme_fg_color @fg_color;
@define-color theme_base_color @base_color;
@define-color theme_text_color @text_color;
@define-color theme_selected_bg_color @selected_bg_color;
@define-color theme_selected_fg_color @selected_fg_color;
@define-color theme_tooltip_bg_color @tooltip_bg_color;
@define-color theme_tooltip_fg_color @tooltip_fg_color;

/* shadow effects */
@define-color light_shadow #eeeeee;
@define-color dark_shadow #222222;

/* misc colors used by gtk+ */
@define-color info_fg_color white;
@define-color info_bg_color #BACF66;
@define-color warning_fg_color white;
@define-color warning_bg_color #E6A682;
@define-color question_fg_color white;
@define-color question_bg_color #74C47B;
@define-color error_fg_color white;
@define-color error_bg_color #E682C8;
@define-color link_color mix (@theme_selected_bg_color, black, 0.15);
@define-color success_color #53a93f;
@define-color warning_color #f57900;
@define-color error_color #cc0000;

/* widget colors*/
@define-color border_color #363D43;
@define-color button_normal_color #3F474A;
@define-color button_info_color #72B279;
@define-color button_default_active_color shade(@theme_selected_bg_color, 0.857);
@define-color entry_border_color shade(@theme_base_color, 0.9);
@define-color frame_border_bottom_color #E3E4E7;
@define-color sel_color #B98CD7;
@define-color switch_bg_color #C9CBCF;
@define-color panel_bg_color @bg_color;
@define-color panel_fg_color @fg_color;
@define-color borders #FAFAFA;
@define-color scrollbar_trough shade(@theme_base_color, 0.9);
@define-color scrollbar_slider_prelight mix(@scrollbar_trough, @theme_fg_color, 0.5);


/* osd */
@define-color osd_separator #49525B;
@define-color osd_fg #ABB4BD;
@define-color osd_bg #434A54;

/* window manager colors */
@define-color wm_bg @theme_bg_color;
@define-color wm_title_focused @theme_fg_color;
@define-color wm_title_unfocused @theme_text_color;
@define-color wm_border_focused @border_color;
@define-color wm_border_unfocused @border_color;

/* -----------------------------------------------------------------------------
 * Keyframes
 * -------------------------------------------------------------------------- */

@keyframes blink-warning {
    70% {
        color: @wm_icon_bg;
    }

    to {
        color: @wm_icon_bg;
        background-color: @warning_color;
    }
}

@keyframes blink-critical {
    70% {
        color: @wm_icon_bg;
    }

    to {
        color: @wm_icon_bg;
        background-color: @error_color;
    }
}

/* -----------------------------------------------------------------------------
 * Base styles
 * -------------------------------------------------------------------------- */

/* Reset all styles */
* {
    border: none;
    border-radius: 0;
    min-height: 0;
    margin: 0;
    padding: 0;
    font-family: "FiraMono NF", "Roboto Mono", sans-serif;
}

/* The whole bar */
window#waybar {
    /*background: @theme_bg_color;*/
    background: mix(@theme_bg_color, transparent, 0.6);
    color: @wm_icon_bg;
    font-size: 14px;
    border-radius: 10px;
}

/* Each module */
#custom-pacman,
#custom-menu,
#custom-help,
#custom-scratchpad,
#custom-github,
#custom-clipboard,
#custom-zeit,
#custom-dnd,
#bluetooth,
#battery,
#clock,
#cpu,
#memory,
#submap,
#network,
#pulseaudio,
#temperature,
#idle_inhibitor,
#backlight,
#language,
#custom-adaptive-light,
#custom-sunset,
#custom-playerctl,
#tray {
    color: @theme_fg_color;
    padding-left: 10px;
    padding-right: 10px;
}

/* -----------------------------------------------------------------------------
 * Module styles
 * -------------------------------------------------------------------------- */

#custom-scratchpad,
#custom-menu,
#workspaces button.focused,
#clock {
    color: @theme_bg_color;
    background-color: @theme_selected_bg_color;
}

#custom-menu {
    border-radius: 10px 0 0 10px;
}

#clock {
    border-radius: 0 10px 10px 0;
}

#custom-zeit.tracking {
    background-color: @warning_color;
}

#battery {
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#battery.warning {
    color: @warning_color;
}

#battery.critical {
    color: @error_color;
}

#battery.warning.discharging {
    animation-name: blink-warning;
    animation-duration: 3s;
}

#battery.critical.discharging {
    animation-name: blink-critical;
    animation-duration: 2s;
}

#clock {
    font-weight: bold;
}

#cpu.warning {
    color: @warning_color;
}

#cpu.critical {
    color: @error_color;
}

#custom-menu {
    padding-left: 8px;
    padding-right: 13px;
}

#memory {
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#memory.warning {
    color: @warning_color;
}

#memory.critical {
    color: @error_color;
    animation-name: blink-critical;
    animation-duration: 2s;
}

#submap {
    background: @background_color;
}

#network.disconnected {
    color: @warning_color;
}

#pulseaudio.muted {
    color: @warning_color;
}

#temperature.critical {
    color: @error_color;
}

#workspaces button {
    border-top: 2px solid transparent;
    /* To compensate for the top border and still have vertical centering */
    padding-bottom: 2px;
    padding-left: 10px;
    padding-right: 10px;
    color: @theme_selected_bg_color;
}

#workspaces button.active {
    border-color: @theme_selected_bg_color;
}

#workspaces button.urgent {
    border-color: @error_color;
    color: @error_color;
}

#custom-pacman {
    color: @warning_color;
}

#bluetooth.disabled {
    color: @warning_color;
}

#custom-wf-recorder {
    color: @error_color;
    padding-right: 10px;
}
    '';
  };
}
