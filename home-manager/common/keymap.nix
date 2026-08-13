{ lib, ... }:
let
  # $mod + [shift +] {1..10} -> [move to] workspace {1..10}
  workspaceBinds = builtins.concatLists (builtins.genList
    (x:
      let
        ws = let c = (x + 1) / 10; in builtins.toString (x + 1 - (c * 10));
        n = toString (x + 1);
      in [
        { mods = [ "mod" ]; key = ws; workspace = n; }
        { mods = [ "mod" "shift" ]; key = ws; moveToWorkspace = n; }
      ])
    10);
in
{
  keymap.mod = "SUPER";

  keymap.binds = [
    { mods = [ "mod" ]; key = "return"; app = "terminal"; }
    { mods = [ "mod" ]; key = "Q"; close = true; }
    {
      mods = [ "mod" ]; key = "M";
      comment = "quit the compositor; AeroSpace has no equivalent";
      raw.hyprland = "exit, ";
    }
    { mods = [ "mod" ]; key = "E"; app = "fileManager"; }
    { mods = [ "mod" "shift" ]; key = "space"; toggleFloat = true; }
    { mods = [ "mod" ]; key = "D"; app = "menu"; }
    {
      mods = [ "mod" ]; key = "P";
      comment = "pseudotiling is a dwindle concept with no AeroSpace analogue";
      raw.hyprland = "pseudo, ";
    }
    { mods = [ "mod" ]; key = "T"; toggleSplit = true; }
    { mods = [ "mod" ]; key = "I"; app = "editor"; }
    { mods = [ "mod" ]; key = "O"; app = "browser"; }
    {
      mods = [ "mod" "shift" ]; key = "C";
      raw.hyprland = "exec, hyprctl reload";
      raw.aerospace = "reload-config";
    }

    { mods = [ "mod" ]; key = "H"; focus = "left"; }
    { mods = [ "mod" ]; key = "L"; focus = "right"; }
    { mods = [ "mod" ]; key = "K"; focus = "up"; }
    { mods = [ "mod" ]; key = "J"; focus = "down"; }
    { mods = [ "mod" "shift" ]; key = "H"; move = "left"; }
    { mods = [ "mod" "shift" ]; key = "L"; move = "right"; }
    { mods = [ "mod" "shift" ]; key = "K"; move = "up"; }
    { mods = [ "mod" "shift" ]; key = "J"; move = "down"; }

    {
      mods = [ "mod" ]; key = "N";
      comment = "AeroSpace has no 'next empty workspace' concept";
      raw.hyprland = "workspace, empty";
    }
    {
      mods = [ "mod" "shift" ]; key = "N";
      raw.hyprland = "movetoworkspace, empty";
    }

    { mods = [ "mod" ]; key = "S"; toggleScratch = "magic"; }
    { mods = [ "mod" "shift" ]; key = "S"; moveToScratch = "magic"; }
    { mods = [ "mod" ]; key = "A"; toggleScratch = "magic2"; }
    { mods = [ "mod" "shift" ]; key = "A"; moveToScratch = "magic2"; }

    { mods = [ "mod" ]; key = "F"; fullscreen = true; }
    {
      mods = [ "mod" "shift" ]; key = "F";
      comment = ''
        Hyprland "fullscreen 0" is maximise-within-layout. AeroSpace's nearest
        thing is macos-native-fullscreen, which creates a Space and fights the
        tiler, so this stays Hyprland-only.
      '';
      raw.hyprland = "fullscreen, 0";
    }

    {
      mods = [ "mod" "shift" ]; key = "p";
      comment = "cliphist picker; no clipboard-history daemon on the Mac";
      raw.hyprland = "exec, cliphist list | wofi --show dmenu --normal-window --lines 14 | cliphist decode | wl-copy";
    }
  ] ++ workspaceBinds;

  keymap.modes = {
    resize = {
      order = 10;
      enter = { mods = [ "mod" ]; key = "r"; };
      binds = [
        { key = "l"; repeat = true; resize = { w = 15; h = 0; }; }
        { key = "h"; repeat = true; resize = { w = -15; h = 0; }; }
        { key = "k"; repeat = true; resize = { w = 0; h = -15; }; }
        { key = "j"; repeat = true; resize = { w = 0; h = 15; }; }
      ];
    };

    # Both of the following have entirely platform-specific bodies — the Linux
    # side is systemctl/loginctl/grimblast — so every bind is `raw`.
    shutdown = {
      order = 20;
      enter = { mods = [ "mod" "shift" ]; key = "e"; };
      binds = [
        {
          key = "l";
          comment = "lock";
          raw.hyprland = "exec,$reset_submap && $locking # lock";
          # Locks given "require password immediately after sleep".
          raw.aerospace = [ "exec-and-forget /usr/bin/pmset displaysleepnow" "mode main" ];
        }
        {
          key = "e";
          comment = "logout";
          raw.hyprland = "exec,$reset_submap && $purge_cliphist; loginctl terminate-user $USER # logout";
          raw.aerospace = [
            "exec-and-forget /usr/bin/osascript -e 'tell application \"System Events\" to log out'"
            "mode main"
          ];
        }
        {
          key = "u";
          comment = "suspend";
          raw.hyprland = "exec,$reset_submap && systemctl suspend # suspend";
          raw.aerospace = [ "exec-and-forget /usr/bin/pmset sleepnow" "mode main" ];
        }
        {
          key = "h";
          comment = "hibernate; macOS has no user-visible equivalent";
          raw.hyprland = "exec,$reset_submap && systemctl hibernate # hibernate";
        }
        {
          key = "s";
          comment = "shutdown";
          raw.hyprland = "exec,$reset_submap && $purge_cliphist; systemctl poweroff # shutdown";
          raw.aerospace = [
            "exec-and-forget /usr/bin/osascript -e 'tell application \"System Events\" to shut down'"
            "mode main"
          ];
        }
        {
          key = "r";
          comment = "reboot";
          raw.hyprland = "exec,$reset_submap && $purge_cliphist; systemctl reboot # reboot";
          raw.aerospace = [
            "exec-and-forget /usr/bin/osascript -e 'tell application \"System Events\" to restart'"
            "mode main"
          ];
        }
      ];
    };

    screenshot = {
      order = 30;
      enter = { key = "print"; };
      # Mac keyboards have no Print key. $mod+P is free on the Mac because
      # pseudotiling is not emitted there.
      aerospace.enter = { mods = [ "mod" ]; key = "P"; };
      binds = [
        {
          key = "a";
          comment = "copy area";
          raw.hyprland = "exec,$reset_submap && grimblast copy area";
          raw.aerospace = [ "exec-and-forget /usr/sbin/screencapture -i -c" "mode main" ];
        }
        {
          key = "s";
          comment = "copy screen";
          raw.hyprland = "exec,$reset_submap && grimblast copy screen";
          raw.aerospace = [ "exec-and-forget /usr/sbin/screencapture -c" "mode main" ];
        }
        {
          mods = [ "shift" ]; key = "a";
          comment = "save area";
          raw.hyprland = "exec,$reset_submap && grimblast save area";
          raw.aerospace = [
            ''exec-and-forget /usr/sbin/screencapture -i "$HOME/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"''
            "mode main"
          ];
        }
        {
          mods = [ "shift" ]; key = "s";
          comment = "save screen";
          raw.hyprland = "exec,$reset_submap && grimblast save screen";
          raw.aerospace = [
            ''exec-and-forget /usr/sbin/screencapture "$HOME/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"''
            "mode main"
          ];
        }
      ];
    };
  };
}
