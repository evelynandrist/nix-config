{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [
    vimiv-qt
  ];
  home.file."vimiv.conf" = {
    target = ".config/vimiv/vimiv.conf";
    text = ''
      [GENERAL]
      style=nix-colors
    '';
  };
  home.file."vimiv-style" = {
    target = ".config/vimiv/styles/nix-colors";
    text = let
      c0 = config.colorScheme.palette.base00;
      c1 = config.colorScheme.palette.base08;
      c2 = config.colorScheme.palette.base0B;
      c3 = config.colorScheme.palette.base0C;
      c4 = config.colorScheme.palette.base07;
      c5 = config.colorScheme.palette.base04;
      c6 = config.colorScheme.palette.base06;
      c7 = config.colorScheme.palette.base0D;
      c8 = config.colorScheme.palette.base02;
      c9 = config.colorScheme.palette.base09;
      cA = config.colorScheme.palette.base0A;
      cB = config.colorScheme.palette.base01;
      cC = config.colorScheme.palette.base03;
      cD = config.colorScheme.palette.base0F;
      cE = config.colorScheme.palette.base0E;
      cF = config.colorScheme.palette.base05;
      # c0 = config.colorScheme.palette.base00;
      # c1 = config.colorScheme.palette.base01;
      # c2 = config.colorScheme.palette.base02;
      # c3 = config.colorScheme.palette.base03;
      # c4 = config.colorScheme.palette.base04;
      # c5 = config.colorScheme.palette.base05;
      # c6 = config.colorScheme.palette.base06;
      # c7 = config.colorScheme.palette.base07;
      # c8 = config.colorScheme.palette.base08;
      # c9 = config.colorScheme.palette.base09;
      # cA = config.colorScheme.palette.base0A;
      # cB = config.colorScheme.palette.base0B;
      # cC = config.colorScheme.palette.base0C;
      # cD = config.colorScheme.palette.base0D;
      # cE = config.colorScheme.palette.base0E;
      # cF = config.colorScheme.palette.base0F;
    in ''
      [STYLE]
      base00 = #${c0}
      base01 = #${c1}
      base02 = #${c2}
      base03 = #${c3}
      base04 = #${c4}
      base05 = #${c5}
      base06 = #${c6}
      base07 = #${c7}
      base08 = #${c8}
      base09 = #${c9}
      base0a = #${cA}
      base0b = #${cB}
      base0c = #${cC}
      base0d = #${cD}
      base0e = #${cE}
      base0f = #${cF}
    '';
  };
}
