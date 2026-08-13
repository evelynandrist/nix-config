{ config, lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  programs.zsh.initContent = lib.mkOrder 1100 ''
    # BSD ls has no --color and there is no dircolors; deliberately not pulling
    # GNU coreutils in, which would replace ls/date/readlink/stat machine-wide.
    export CLICOLOR=1
    alias ls='ls -G'
  '';
}
