# Pure-data keymap. No renderer logic lives here — see ./hyprland.nix and
# ./aerospace.nix, which turn this into compositor configuration.
#
# The point of the split is that one description of "what the keys do" feeds
# both machines, so switching to the Mac over the KVM lands on the same keys.
{ lib, ... }:
let
  inherit (lib) mkOption types;

  direction = types.enum [ "left" "right" "up" "down" ];

  rawType = types.submodule {
    options = {
      hyprland = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Verbatim tail of a Hyprland bind line, i.e. everything after the key:
          `dispatcher, args`. null means "do not emit this bind on Hyprland".

          Note the separator style differs by context, because the existing
          config does: top-level binds are written `dispatcher, args`, binds
          inside a submap are written `dispatcher,args`.
        '';
      };
      aerospace = mkOption {
        type = types.nullOr (types.either types.str (types.listOf types.str));
        default = null;
        description = ''
          Verbatim AeroSpace command, or a list of commands run in order.
          null means "do not emit this bind on AeroSpace".
        '';
      };
    };
  };

  bindType = types.submodule {
    options = {
      mods = mkOption {
        type = types.listOf (types.enum [ "mod" "shift" ]);
        default = [ ];
        description = ''
          Abstract modifiers. "mod" is Super on Hyprland and Alt/Option on
          AeroSpace; Deskflow maps Super to Option so both land on the same
          physical key.
        '';
      };
      key = mkOption {
        type = types.str;
        description = "Key name, in Hyprland spelling (e.g. `return`, `escape`).";
      };
      repeat = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Hold-to-repeat. Renders as `binde` on Hyprland; a no-op on AeroSpace,
          which repeats held keys natively.
        '';
      };
      comment = mkOption {
        type = types.str;
        default = "";
        description = "Documentation only; not rendered.";
      };

      # --- action vocabulary; at most one of these is set per bind ---
      focus = mkOption { type = types.nullOr direction; default = null; };
      move = mkOption { type = types.nullOr direction; default = null; };
      resize = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            w = mkOption { type = types.int; default = 0; };
            h = mkOption { type = types.int; default = 0; };
          };
        });
        default = null;
      };
      workspace = mkOption { type = types.nullOr types.str; default = null; };
      moveToWorkspace = mkOption { type = types.nullOr types.str; default = null; };
      close = mkOption { type = types.bool; default = false; };
      fullscreen = mkOption { type = types.bool; default = false; };
      toggleFloat = mkOption { type = types.bool; default = false; };
      toggleSplit = mkOption { type = types.bool; default = false; };
      app = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Key into `keymap.apps`. If that host maps the name to null, the bind
          is not emitted there.
        '';
      };
      mode = mkOption { type = types.nullOr types.str; default = null; };
      toggleScratch = mkOption { type = types.nullOr types.str; default = null; };
      moveToScratch = mkOption { type = types.nullOr types.str; default = null; };
      raw = mkOption {
        type = rawType;
        default = { };
        description = "Escape hatch for anything with no portable spelling.";
      };
    };
  };

  chordType = types.submodule {
    options = {
      mods = mkOption {
        type = types.listOf (types.enum [ "mod" "shift" ]);
        default = [ ];
      };
      key = mkOption { type = types.str; };
    };
  };

  modeType = types.submodule {
    options = {
      order = mkOption {
        type = types.int;
        default = 100;
        description = ''
          Emission order. Hyprland submaps are order-dependent text, so this
          keeps the generated block stable instead of alphabetical.
        '';
      };
      enter = mkOption {
        type = chordType;
        description = "Chord that enters the mode from the root map.";
      };
      binds = mkOption {
        type = types.listOf bindType;
        default = [ ];
      };

      hyprland = {
        enable = mkOption { type = types.bool; default = true; };
        label = mkOption {
          type = types.str;
          default = "";
          description = ''
            Pango markup assigned to `$submap_<name>`, which waybar's submap
            module displays. AeroSpace mode names are plain identifiers with no
            display concept, which is why a mode's identity and its label are
            separate things here.
          '';
        };
        extraLines = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Raw hyprlang emitted directly after the label line and before the
            enter bind — variable definitions the submap's binds refer to.
          '';
        };
      };

      aerospace = {
        enable = mkOption { type = types.bool; default = true; };
        enter = mkOption {
          type = types.nullOr chordType;
          default = null;
          description = ''
            Override for the enter chord, for keys macOS keyboards do not have
            (`print`). null means use `enter`.
          '';
        };
      };
    };
  };
in
{
  options.keymap = {
    mod = mkOption {
      type = types.str;
      default = "SUPER";
      description = "Physical modifier `mod` resolves to on Hyprland.";
    };

    apps = mkOption {
      type = types.attrsOf (types.nullOr types.str);
      default = { };
      description = ''
        Application launch commands, per host. Values must be absolute store
        paths on the AeroSpace side: AeroSpace runs as a launchd agent, and its
        `exec-and-forget` shell has no ~/.nix-profile/bin, so a bare command
        name silently does nothing. null means "this host has no such app".
      '';
    };

    binds = mkOption {
      type = types.listOf bindType;
      default = [ ];
      description = "Root-map binds, in emission order.";
    };

    modes = mkOption {
      type = types.attrsOf modeType;
      default = { };
      description = "Modal maps (Hyprland submaps / AeroSpace modes).";
    };
  };
}
