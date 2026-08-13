{ config, lib, pkgs, ... }:
# keymap -> AeroSpace.
#
# Unlike the Hyprland renderer this has a single output: AeroSpace's config is
# TOML, and its modes are plain attrsets with no ordering constraints.
let
  inherit (lib) mkOption types;

  km = config.keymap;
  cfg = km.aerospace;

  aerospaceBin = lib.getExe config.programs.aerospace.package;

  # AeroSpace switches to the scratchpad workspace rather than overlaying it on
  # the current one, which is the accepted behavioural difference from
  # Hyprland's special workspaces. Toggling back out is workspace-back-and-forth.
  scratch = pkgs.writeShellScriptBin "aerospace-scratch" ''
    ws="${cfg.scratchPrefix}$1"
    if [ "$(${aerospaceBin} list-workspaces --focused)" = "$ws" ]; then
      ${aerospaceBin} workspace-back-and-forth
    else
      ${aerospaceBin} workspace "$ws"
    fi
  '';

  # Hyprland key spellings -> AeroSpace ones. null means the key does not exist
  # on a Mac keyboard, so the bind is dropped (use `aerospace.enter` or a
  # `raw` entry to give it a home).
  keyNames = {
    return = "enter";
    escape = "esc";
    print = null;
  };
  aKey = k: let l = lib.toLower k; in keyNames.${l} or l;

  # Deskflow maps Super -> Option, so `mod` is alt here and the chord lands on
  # the same physical key as on nixpad.
  modsPrefix = mods:
    lib.concatMapStrings (m: (if m == "mod" then "alt" else m) + "-") mods;

  sign = n: if n >= 0 then "+${toString n}" else toString n;

  app = b: km.apps.${b.app} or null;

  cmd = b:
    if b.raw.aerospace != null then b.raw.aerospace
    else if b.raw.hyprland != null then null # deliberately Hyprland-only
    else if b.focus != null then "focus ${b.focus}"
    else if b.move != null then "move ${b.move}"
    else if b.resize != null then
      (let
        parts =
          lib.optional (b.resize.w != 0) "resize width ${sign b.resize.w}"
          ++ lib.optional (b.resize.h != 0) "resize height ${sign b.resize.h}";
      in
        if parts == [ ] then null
        else if lib.length parts == 1 then lib.head parts
        else parts)
    else if b.workspace != null then "workspace ${b.workspace}"
    else if b.moveToWorkspace != null then "move-node-to-workspace ${b.moveToWorkspace}"
    else if b.close then "close"
    else if b.fullscreen then "fullscreen"
    else if b.toggleFloat then "layout floating tiling"
    else if b.toggleSplit then "layout horizontal vertical"
    else if b.mode != null then
      (if (km.modes.${b.mode}.aerospace.enable or false) then "mode ${b.mode}" else null)
    else if b.toggleScratch != null then
      "exec-and-forget ${scratch}/bin/aerospace-scratch ${b.toggleScratch}"
    else if b.moveToScratch != null then
      "move-node-to-workspace ${cfg.scratchPrefix}${b.moveToScratch}"
    else if b.app != null then
      (if app b == null then null else "exec-and-forget ${app b}")
    else null;

  binding = b:
    let
      key = aKey b.key;
      command = cmd b;
    in
      if key == null || command == null then null
      else lib.nameValuePair "${modsPrefix b.mods}${key}" command;

  bindingsOf = binds:
    lib.listToAttrs (builtins.filter (x: x != null) (map binding binds));

  activeModes = lib.filterAttrs (_: m: m.aerospace.enable) km.modes;

  enterBinding = name: m:
    let
      e = if m.aerospace.enter != null then m.aerospace.enter else m.enter;
      key = aKey e.key;
    in
      if key == null then null
      else lib.nameValuePair "${modsPrefix e.mods}${key}" "mode ${name}";

  enterBindings = lib.listToAttrs
    (builtins.filter (x: x != null) (lib.mapAttrsToList enterBinding activeModes));

  modeSettings = lib.mapAttrs
    (_: m: {
      binding = bindingsOf m.binds // { esc = "mode main"; };
    })
    activeModes;
in
{
  imports = [ ./default.nix ];

  options.keymap.aerospace = {
    scratchPrefix = mkOption {
      type = types.str;
      default = ".scratch-";
      description = ''
        Prefix for scratchpad workspace names. The leading dot sorts them out
        of the way in `aerospace list-workspaces`; if AeroSpace turns out to
        reject a leading dot in workspace names, change it here.
      '';
    };
  };

  config = lib.mkIf (config.programs.aerospace.enable && (km.binds != [ ] || km.modes != { })) {
    home.packages = [ scratch ];

    programs.aerospace.settings.mode = {
      main.binding = bindingsOf km.binds // enterBindings;
    } // modeSettings;
  };
}
