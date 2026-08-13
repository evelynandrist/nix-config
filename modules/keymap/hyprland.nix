{ config, lib, ... }:
# keymap -> Hyprland.
#
# This renderer has two outputs, not one:
#
#   settings.bind / settings.binde   an unordered attrset-shaped list
#   extraConfig                      raw hyprlang text
#
# The submaps cannot live in settings.bind: hyprlang submaps are order
# dependent (`submap=X` opens a block, every following `bind=` belongs to it,
# `submap=reset` closes it) and have no attrset representation. So modes are
# emitted as text and everything else as structure.
let
  km = config.keymap;

  dir = {
    left = "l";
    right = "r";
    up = "u";
    down = "d";
  };

  modsStr = mods:
    lib.concatStringsSep " "
      (map (m: if m == "mod" then "$mod" else lib.toUpper m) mods);

  # Everything after the key. `sep` is ", " at the root and "," inside a
  # submap, matching how the hand-written config was spelled.
  tail = sep: b:
    if b.raw.hyprland != null then b.raw.hyprland
    else if b.focus != null then "movefocus${sep}${dir.${b.focus}}"
    else if b.move != null then "movewindow${sep}${dir.${b.move}}"
    else if b.resize != null then "resizeactive${sep}${toString b.resize.w} ${toString b.resize.h}"
    else if b.workspace != null then "workspace${sep}${b.workspace}"
    else if b.moveToWorkspace != null then "movetoworkspace${sep}${b.moveToWorkspace}"
    else if b.close then "killactive,"
    else if b.fullscreen then "fullscreen${sep}1"
    else if b.toggleFloat then "togglefloating,"
    else if b.toggleSplit then "layoutmsg${sep}togglesplit"
    else if b.mode != null then "submap${sep}$submap_${b.mode}"
    else if b.toggleScratch != null then "togglespecialworkspace${sep}${b.toggleScratch}"
    else if b.moveToScratch != null then "movetoworkspace${sep}special:${b.moveToScratch}"
    else if b.app != null then "exec${sep}${km.apps.${b.app}}"
    else throw "keymap: bind ${modsStr b.mods}+${b.key} has no action Hyprland can render";

  hasAction = b:
    b.focus != null || b.move != null || b.resize != null
    || b.workspace != null || b.moveToWorkspace != null
    || b.close || b.fullscreen || b.toggleFloat || b.toggleSplit
    || b.mode != null || b.toggleScratch != null || b.moveToScratch != null
    || b.app != null;

  # A bind is skipped when it is deliberately Hyprland-less (raw with no
  # hyprland side), or when it launches an app this host does not have.
  emit = b:
    (b.raw.hyprland != null || hasAction b)
    && !(b.app != null && (km.apps.${b.app} or null) == null);

  rootBinds = builtins.filter emit km.binds;

  rootLine = b: "${modsStr b.mods}, ${b.key}, ${tail ", " b}";
  submapLine = b:
    "${if b.repeat then "binde" else "bind"}=${modsStr b.mods},${b.key},${tail "," b}";

  modes = lib.sortOn (m: [ m.value.order m.name ])
    (lib.mapAttrsToList (name: value: { inherit name value; })
      (lib.filterAttrs (_: m: m.hyprland.enable) km.modes));

  modeBlock = { name, value }:
    lib.concatStringsSep "\n" (
      [ "$submap_${name} = ${value.hyprland.label}" ]
      ++ value.hyprland.extraLines
      ++ [
        "bind=${modsStr value.enter.mods},${value.enter.key},submap,$submap_${name}"
        "submap=$submap_${name}"
      ]
      ++ map submapLine (builtins.filter emit value.binds)
      ++ [
        "bind=,escape,submap,reset"
        "submap=reset"
      ]
    );
in
{
  imports = [ ./default.nix ];

  config = lib.mkIf (km.binds != [ ] || km.modes != { }) {
    wayland.windowManager.hyprland = {
      settings =
        {
          bind = map rootLine (builtins.filter (b: !b.repeat) rootBinds);
        }
        // lib.optionalAttrs (builtins.any (b: b.repeat) rootBinds) {
          binde = map rootLine (builtins.filter (b: b.repeat) rootBinds);
        };

      # Order sensitive, so it has to be text.
      extraConfig = lib.concatMapStrings (m: modeBlock m + "\n") modes;
    };
  };
}
