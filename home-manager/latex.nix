{ config, lib, pkgs, ... }: {
  programs.texlive = {
    enable = true;
    extraPackages = tpkgs: { inherit (tpkgs) scheme-full; };
  };
  programs.zathura = {
    enable = true;
    options = {
      default-bg = "#${config.colorScheme.palette.base00}";
      default-fg = "#${config.colorScheme.palette.base0F}";
    };
  };
}
