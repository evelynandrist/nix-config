{ config, lib, pkgs, inputs, ... }: {
  home.packages = with pkgs; [
    terminal-magic
  ];

  home.file."color-sequences.sh" = {
    target = ".config/color-sequences.sh";
    executable = true;
    text = let
      # c0 = config.colorScheme.palette.base00;
      # c1 = config.colorScheme.palette.base08;
      # c2 = config.colorScheme.palette.base0B;
      # c3 = config.colorScheme.palette.base0C;
      # c4 = config.colorScheme.palette.base07;
      # c5 = config.colorScheme.palette.base04;
      # c6 = config.colorScheme.palette.base06;
      # c7 = config.colorScheme.palette.base0D;
      # c8 = config.colorScheme.palette.base02;
      # c9 = config.colorScheme.palette.base09;
      # cA = config.colorScheme.palette.base0A;
      # cB = config.colorScheme.palette.base01;
      # cC = config.colorScheme.palette.base03;
      # cD = config.colorScheme.palette.base0F;
      # cE = config.colorScheme.palette.base0E;
      # cF = config.colorScheme.palette.base05;
      c0 = config.colorScheme.palette.base00;
      c1 = config.colorScheme.palette.base01;
      c2 = config.colorScheme.palette.base02;
      c3 = config.colorScheme.palette.base03;
      c4 = config.colorScheme.palette.base04;
      c5 = config.colorScheme.palette.base05;
      c6 = config.colorScheme.palette.base06;
      c7 = config.colorScheme.palette.base07;
      c8 = config.colorScheme.palette.base08;
      c9 = config.colorScheme.palette.base09;
      cA = config.colorScheme.palette.base0A;
      cB = config.colorScheme.palette.base0B;
      cC = config.colorScheme.palette.base0C;
      cD = config.colorScheme.palette.base0D;
      cE = config.colorScheme.palette.base0E;
      cF = config.colorScheme.palette.base0F;
    in ''
printf "\033]4;0;#${c0}\033\\"
printf "\033]4;1;#${c1}\033\\"
printf "\033]4;2;#${c2}\033\\"
printf "\033]4;3;#${c3}\033\\"
printf "\033]4;4;#${c4}\033\\"
printf "\033]4;5;#${c5}\033\\"
printf "\033]4;6;#${c6}\033\\"
printf "\033]4;7;#${c7}\033\\"
printf "\033]4;8;#${c8}\033\\"
printf "\033]4;9;#${c9}\033\\"
printf "\033]4;10;#${cA}\033\\"
printf "\033]4;11;#${cB}\033\\"
printf "\033]4;12;#${cC}\033\\"
printf "\033]4;13;#${cD}\033\\"
printf "\033]4;14;#${cE}\033\\"
printf "\033]4;15;#${cF}\033\\"
printf "\033]10;#${cF}\033\\"
printf "\033]11;#${c0}\033\\"
printf "\033]12;#${cF}\033\\"
printf "\033]13;#${cF}\033\\"
printf "\033]17;#${cF}\033\\"
printf "\033]19;#${c0}\033\\"
printf "\033]232;#${c0}\033\\"
printf "\033]256;#${cF}\033\\"
printf "\033]257;#${c0}\033\\"
printf "\033]708;#${c0}\033\\"
    '';
  };

  programs.zsh.initExtra = ''
# needed for UbiqueInnovation terminal-magic-cli
source ~/.terminal-magic/env
  '';
}
