{ config, lib, ... }:
# keymap -> Hyprland (Lua config, Hyprland >= 0.55).
#
# Everything is emitted as Lua text into extraConfig rather than through
# `settings`: binds and submaps are order dependent (a submap's binds are
# registered inside its `hl.define_submap` callback), and home-manager's
# `settings` renders attributes alphabetically.
let
  km = config.keymap;

  toLua = lib.generators.toLua { };

  keys = mods: key:
    lib.concatStringsSep " + "
      ((map (m: if m == "mod" then km.mod else lib.toUpper m) mods) ++ [ key ]);

  # Workspace selectors: plain ids are Lua integers, everything else
  # ("empty", "special:magic", "e+1") is a string.
  ws = w: if builtins.match "[0-9]+" w != null then w else toLua w;

  # The dispatcher expression for a bind.
  action = b:
    if b.raw.hyprland != null then b.raw.hyprland
    else if b.focus != null then "hl.dsp.focus({ direction = ${toLua b.focus} })"
    else if b.move != null then "hl.dsp.window.move({ direction = ${toLua b.move} })"
    else if b.resize != null then
      "hl.dsp.window.resize({ x = ${toString b.resize.w}, y = ${toString b.resize.h}, relative = true })"
    else if b.workspace != null then "hl.dsp.focus({ workspace = ${ws b.workspace} })"
    else if b.moveToWorkspace != null then "hl.dsp.window.move({ workspace = ${ws b.moveToWorkspace} })"
    else if b.close then "hl.dsp.window.close()"
    # "maximized" keeps bars and gaps; real fullscreen is a raw bind.
    else if b.fullscreen then ''hl.dsp.window.fullscreen({ mode = "maximized" })''
    else if b.toggleFloat then ''hl.dsp.window.float({ action = "toggle" })''
    else if b.toggleSplit then ''hl.dsp.layout("togglesplit")''
    else if b.mode != null then "hl.dsp.submap(${submapName b.mode})"
    else if b.toggleScratch != null then "hl.dsp.workspace.toggle_special(${toLua b.toggleScratch})"
    else if b.moveToScratch != null then
      "hl.dsp.window.move({ workspace = ${toLua "special:${b.moveToScratch}"} })"
    else if b.app != null then "hl.dsp.exec_cmd(${toLua km.apps.${b.app}})"
    else throw "keymap: bind ${keys b.mods b.key} has no action Hyprland can render";

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

  bindLine = indent: b:
    "${indent}hl.bind(${toLua (keys b.mods b.key)}, ${action b}"
    + lib.optionalString b.repeat ", { repeating = true }"
    + ")";

  # A submap's name is its label: waybar's hyprland/submap module displays
  # the submap name, so the Pango markup has to be the name itself.
  submapName = name:
    let label = km.modes.${name}.hyprland.label;
    in toLua (if label != "" then label else name);

  modes = lib.sortOn (m: [ m.value.order m.name ])
    (lib.mapAttrsToList (name: value: { inherit name value; })
      (lib.filterAttrs (_: m: m.hyprland.enable) km.modes));

  modeBlock = { name, value }:
    lib.concatStringsSep "\n" (
      [
        "hl.bind(${toLua (keys value.enter.mods value.enter.key)}, hl.dsp.submap(${submapName name}))"
        ("hl.define_submap(${submapName name}, "
          + lib.optionalString value.hyprland.resetOnDispatch ''"reset", ''
          + "function()")
      ]
      ++ map (bindLine "  ") (builtins.filter emit value.binds)
      ++ [
        "  hl.bind(\"escape\", hl.dsp.submap(\"reset\"))"
        "end)"
      ]
    );
in
{
  imports = [ ./default.nix ];

  config = lib.mkIf (km.binds != [ ] || km.modes != { }) {
    wayland.windowManager.hyprland.extraConfig =
      lib.concatMapStrings (b: bindLine "" b + "\n") (builtins.filter emit km.binds)
      + lib.concatMapStrings (m: modeBlock m + "\n") modes;
  };
}
