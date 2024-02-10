{ lib, config, inputs, pkgs, ... }:
with lib;
let
  cfg = config.moewalls;
  fetchVideo = import ./get-video.nix { inherit pkgs; };
  nix-colors-lib = inputs.nix-colors.lib.contrib { inherit pkgs; };
in {
  imports = [ ];
  options.moewalls = {
    url = mkOption {
      type = types.str;
      description = "Url of the wallpaper from moewalls.com.";
      default = "https://moewalls.com/landscape/chill-seashore-live-wallpaper/";
    };
    width = mkOption {
      type = types.int;
      description = "Width of the resulting wallpaper.";
      default = 1920;
    };
    height = mkOption {
      type = types.int;
      description = "Height of the resulting wallpaper.";
      default = 1080;
    };
    display = mkOption {
      type = types.str;
      description = "Output display for mpvpaper.";
      default = "eDP-1";
    };
    ffmpegThreads = mkOption {
      type = types.int;
      description = "Number of ffmpeg threads to use for transcoding the video to a lower resolution.";
      default = 14;
    };
    variant = mkOption {
      type = types.enum [ "light" "dark" ];
      description = "Variant of the generated color scheme. Gets passed to nix-colors.";
      default = "dark";
    };
  };

  config =
    let
      wallpaperFolder = fetchVideo {
        url = cfg.url;
        width = toString cfg.width;
        height = toString cfg.height;
        ffmpegThreads = toString cfg.ffmpegThreads;
      };
    in {
      colorScheme = nix-colors-lib.colorSchemeFromPicture {
        path = "${wallpaperFolder}/wallpaper.jpg";
        variant = cfg.variant;
      };
      wayland.windowManager.hyprland.settings.exec = [
        "pkill mpvpaper; mpvpaper -o 'loop' ${cfg.display} ${wallpaperFolder}/wallpaper.mp4"
      ];
    };
}
