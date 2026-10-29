{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    sunshine
  ];

  targets.darwin.defaults = {
    "pro.betterdisplay.BetterDisplay" = {
      "SUEnableAutomaticChecks" = true;
      "enableCLI" = true;
      "startAtLogin" = true;
    };
  };

  # Reconnect the virtual screen sunshine captures after a headless boot.
  # The screen was created once with (16:10 to match the nixpad's 3840x2400):
  #   BetterDisplay create -type=VirtualScreen -virtualScreenName=Sunshine \
  #     -aspectWidth=16 -aspectHeight=10 -sizeInch=24
  # and runs at 2560x1600 non-HiDPI: capturing a HiDPI backing store made
  # streaming laggy (4x the pixels per frame). Mode changes via the CLI only
  # apply while a display is awake (`caffeinate -u` first when headless).
  # `set -connected=on` is idempotent (unlike `create`, which would add a
  # duplicate screen every login). The CLI invocation blocks until the
  # BetterDisplay app is up, so no ordering with its login launch is needed.
  launchd.agents.betterdisplay-connect = {
    enable = true;
    config = {
      ProgramArguments = [
        "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
        "set"
        "-namelike=Sunshine"
        "-connected=on"
      ];
      RunAtLoad = true;
    };
  };

  # A locked session turns displays off on its own timer, IGNORING
  # `power.sleep.display = "never"` — and with no display composing, sunshine
  # has no frames and Moonlight sees the host as offline. caffeinate -d holds a
  # PreventUserIdleDisplaySleep assertion that also applies while locked, so
  # the lock screen stays streamable and can be unlocked through Moonlight.
  launchd.agents.caffeinate = {
    enable = true;
    config = {
      ProgramArguments = [ "/usr/bin/caffeinate" "-d" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  launchd.agents.sunshine = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.sunshine}/bin/sunshine" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/sunshine.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/sunshine.err";
    };
  };

  home.file.".config/sunshine/sunshine.conf".text = ''
    # Sunshine configuration options
    min_threads = 2
    port = 47989
    csrf_allowed_origins = https://nixbook.local:47990
  '';

  home.file.".config/sunshine/apps.json".text = builtins.toJSON {
    env = {
      PATH = "$(PATH):/run/current-system/sw/bin";
    };
    apps = [
      {
	name = "Desktop";
	image-path = "desktop.png";
      }
    ];
  };
}
