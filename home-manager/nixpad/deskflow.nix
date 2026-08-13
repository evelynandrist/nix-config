{ config, lib, pkgs, ... }:
let
  layout = pkgs.writeText "deskflow-layout.conf" ''
    section: screens
      nixpad:
        halfDuplexCapsLock = false
        halfDuplexNumLock = false
        halfDuplexScrollLock = false
        xtestIsXineramaUnaware = false
        preserveFocus = false
        switchCorners = none
        switchCornerSize = 0
      nixbook:
        # Land $mod on the same physical key as on nixpad, and let Ctrl+C/V
        # behave natively in Mac apps. This modifier remapping is the reason
        # Deskflow was chosen over lan-mouse, which cannot do it.
        super = alt
        ctrl = meta
        halfDuplexCapsLock = false
        halfDuplexNumLock = false
        halfDuplexScrollLock = false
        xtestIsXineramaUnaware = false
        preserveFocus = false
        switchCorners = none
        switchCornerSize = 0
    end

    section: links
      # With ONE monitor and two inputs, delete this section: edge capture would send the pointer onto a
      # screen that is not currently being displayed, and the hotkeys below are
      # the switching mechanism instead.
      nixpad:
        up = nixbook
      nixbook:
        down = nixpad
    end

    section: aliases
      nixbook:
        nixbook.local
    end

    section: options
      # Deliberate switching, independent of the layout above, for when the
      # monitor is showing the other machine's input.
      keystroke(super+shift+grave) = switchToScreen(nixbook)
      keystroke(super+shift+escape) = switchToScreen(nixpad)
      clipboardSharing = true
      screenSaverSync = false
      relativeMouseMoves = false
    end
  '';

  # Only used to seed the file on first run; everything here is subsequently
  # owned by Deskflow itself.
  settingsSeed = pkgs.writeText "Deskflow.conf" ''
    [core]
    coreMode=2
    computerName=nixpad
    port=24800
    ; wl-clipboard backend, without which clipboard sharing does nothing on
    ; a Wayland session.
    wlClipboard=true

    [server]
    externalConfig=true
    externalConfigFile=${layout}

    [security]
    tlsEnabled=true
    ; The Mac's fingerprint is confirmed once, interactively, on first connect.
    checkPeerFingerprints=true
  '';

  settingsPath = "${config.xdg.configHome}/Deskflow/Deskflow.conf";
in
{
  home.packages = [ pkgs.deskflow ];

  home.activation.deskflowSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${settingsPath}" ]; then
      run mkdir -p "$(dirname ${lib.escapeShellArg settingsPath})"
      run install -m600 ${settingsSeed} ${lib.escapeShellArg settingsPath}
    fi
  '';

  systemd.user.services.deskflow-server = {
    Unit = {
      Description = "Deskflow server (keyboard, mouse and clipboard sharing)";
      # Started before the compositor it comes up without WAYLAND_DISPLAY and
      # fails the portal handshake — the most common way this breaks.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.deskflow}/bin/deskflow-core server --new-instance";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
