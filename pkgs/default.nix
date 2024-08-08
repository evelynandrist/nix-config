# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  terminal-magic = pkgs.pkgs.callPackage ./terminal-magic { };
  steamlink = pkgs.pkgs.callPackage ./steamlink { };
}
