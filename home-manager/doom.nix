{ config, lib, pkgs, inputs, ... }: {
  home.packages = with pkgs; [
    binutils
    (ripgrep.override { withPCRE2 = true; })
    gnutls
    fd
    imagemagick
    zstd
    nodePackages.javascript-typescript-langserver
    sqlite
    editorconfig-core-c
    emacs-all-the-icons-fonts
  ];
  programs.emacs.enable = true;
  home.sessionPath = [ "${config.xdg.configHome}/emacs/bin" "${config.home.homeDirectory}/.emacs.d/bin" "${pkgs.emacs}/bin" "${pkgs.git}" ];
  home.sessionVariables = {
    DOOMDIR = "${config.xdg.configHome}/doom-config";
    DOOMLOCALDIR = "${config.xdg.configHome}/doom-local";
    DOOMPROFILELOADFILE = "${config.xdg.configHome}/doom-local/load.el";
  };
  xdg = {
    enable = true;
    configFile = {
      "doom-config".source = ./doom-config;
      "emacs" = {
        source = inputs.doom-emacs;
        onChange = "${pkgs.writeShellScript "doom-change" ''
          export DOOMDIR="${config.home.sessionVariables.DOOMDIR}"
          export DOOMLOCALDIR="${config.home.sessionVariables.DOOMLOCALDIR}"
          export DOOMPROFILELOADFILE="${config.home.sessionVariables.DOOMPROFILELOADFILE}"
          export PATH="$PATH:${pkgs.emacs}/bin"
          export PATH="$PATH:${pkgs.git}/bin"
          export PATH="$PATH:${pkgs.imagemagick}/bin"
          export PATH="$PATH:${pkgs.ripgrep}/bin"
          export PATH="$PATH:${pkgs.fd}/bin"
          export PATH="$PATH:${pkgs.sqlite}/bin"
          if [ ! -d "$DOOMLOCALDIR" ]; then
            ${config.xdg.configHome}/emacs/bin/doom install --force
          else
            ${config.xdg.configHome}/emacs/bin/doom --force clean
            ${config.xdg.configHome}/emacs/bin/doom --force sync -u
          fi
        ''}";
      };
    };
  };
}
