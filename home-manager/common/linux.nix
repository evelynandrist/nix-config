{ config, lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.isLinux {
  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs.zsh.initContent = lib.mkOrder 1100 ''
    alias backup="sudo systemctl start restic-backups-pcloud.service"

    # File and Dir colors for ls and other outputs (GNU coreutils only)
    export LS_OPTIONS='--color=auto'
    eval "$(dircolors -b)"
    alias ls='ls $LS_OPTIONS'
  '';
}
