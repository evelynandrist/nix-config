# This file defines overlays
{inputs, ...}: let
  addPatches = pkg: patches: pkg.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ patches;
  });
in {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final;};

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    pcmanfm = prev.pcmanfm.override { withGtk3 = true; };
    waybar = addPatches prev.waybar [
      ./waybar_markup.patch # add support for pangu markup to the hyprland/submaps module
      ./waybar_workspaces.patch # fix a bug in the hyprland/workspaces module
    ];
    inputs.nix-pkgs-24-05.qemu = addPatches prev.qemu [
      ./qemu-8.2.0.patch # anti-detection qemu
    ];
    # change colorSchemeFromPicture backend from flavours to wpgtk
    # nix-colors = addPatches prev.nix-colors [ ./nix-colors-wpgtk.patch ];
    /*nix-colors = prev.nix-colors.overrideAttrs (old: {
      patches = (old.patches or []) ++ [ ./nix-colors-wpgtk.patch ];
    });*/
  };

  # When applied, the master (branch) nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.master'
  master-packages = final: _prev: {
    master = import inputs.nixpkgs-master {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
