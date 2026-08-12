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
      default = "'*'";
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
    mpvOptions = mkOption {
      type = types.str;
      description = ''
        Options forwarded to mpv by mpvpaper. hwdec offloads decoding to the GPU's
        video engine, without it mpv decodes in software and burns whole CPU cores
        just to draw the wallpaper.
      '';
      default = "loop panscan=1.0 no-audio hwdec=vaapi vd-lavc-threads=2";
    };
    autoPause = mkOption {
      type = types.bool;
      description = "Pause the wallpaper while it is covered by other windows.";
      default = true;
    };
    static = mkOption {
      type = types.bool;
      description = ''
        Show the still frame with hyprpaper instead of playing the video with
        mpvpaper. The colour scheme is derived from that same still either way,
        so this only removes the motion.

        Worth it on an APU: the video costs roughly a third of the iGPU, which
        matters most when a CPU-heavy task has taken the shared power budget and
        the GPU gets clocked down.
      '';
      default = false;
    };
    image = mkOption {
      type = types.nullOr types.path;
      description = ''
        Use this image as the wallpaper instead of fetching a video from moewalls.
        Nothing is downloaded or transcoded, and the colour scheme is derived from
        this image. Implies `static`, since there is no video to play.
      '';
      default = null;
      example = literalExpression "./wallpapers/forest.png";
    };
  };

  config =
    let
      # Only forced when no image is given, so setting `image` skips the fetch
      # and the transcode entirely.
      wallpaperFolder = fetchVideo {
        url = cfg.url;
        width = toString cfg.width;
        height = toString cfg.height;
        ffmpegThreads = toString cfg.ffmpegThreads;
      };

      useImage = cfg.image != null;
      still = if useImage then cfg.image else "${wallpaperFolder}/wallpaper.jpg";
      showStill = cfg.static || useImage;
    in mkMerge [
      {
        colorScheme = nix-colors-lib.colorSchemeFromPicture {
          path = still;
          variant = cfg.variant;
        };
      }

      # swaybg rather than hyprpaper: hyprpaper 0.8.4 ignores its config file
      # entirely (every monitor logs "has no target"), and setting the wallpaper over
      # its IPC does not survive the unit's own Restart=always, nor does it cover
      # monitors plugged in later. swaybg takes the image as an argument, so both
      # come for free.
      (mkIf showStill {
        systemd.user.services.swaybg = {
          Unit = {
            Description = "Static wallpaper";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
            ConditionEnvironment = "WAYLAND_DISPLAY";
          };
          Service = {
            ExecStart = ''${pkgs.swaybg}/bin/swaybg --image "${still}" --mode fill'';
            Restart = "always";
            RestartSec = 5;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })

      (mkIf (!showStill) {
        wayland.windowManager.hyprland.settings.exec = [
          "pkill mpvpaper; mpvpaper ${optionalString cfg.autoPause "--auto-pause "}-o '${cfg.mpvOptions}' ${cfg.display} ${wallpaperFolder}/wallpaper.mp4"
        ];
      })
    ];
}
