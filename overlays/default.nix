# This file defines overlays
{inputs, nixpkgs, ...}: let
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
    vimPlugins = prev.vimPlugins.extend (final': prev': {
      himalaya-vim = prev.vimPlugins.himalaya-vim.overrideAttrs {
      src = prev.fetchgit {
	url = "https://git.sr.ht/~soywod/himalaya-vim";
	rev = "cea041c927a04a841aea53abcedd4a0d153d4ca8";
	sha256 = "0yrilhvqklfbfknkdskywf95mfhbr9rfjs2gmppnzgfs7fg6jn63";
      };
      };
    });

 #    himalaya = prev.himalaya.overrideAttrs (old: rec {
 #      name = "himalaya-${version}";
 #      version = "1.0.0-beta.3";
	#
 #      src = prev.fetchFromGitHub {
	# owner = "soywod";
	# repo = "himalaya";
	# rev = "v1.0.0-beta.3";
	# hash = "sha256-B7eswDq4tKyg881i3pLd6h+HsObK0c2dQnYuvPAGJHk=";
 #      };
	#
 #      cargoDeps = old.cargoDeps.overrideAttrs (nixpkgs.lib.const {
	# name = "${name}-vendor.tar.gz";
	# inherit src;
	# outputHash = "sha256-jOzuCXsrtXp8dmJTBqrEq4nog6smEPbdsFAy+ruPtY8=";
 #      });
 #    });
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
