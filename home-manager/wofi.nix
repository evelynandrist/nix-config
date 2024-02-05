{ config, lib, pkgs, inputs, ... }: {
  programs.wofi = {
    enable = true;
    style = let
      c0 = inputs.nix-colors.lib-core.conversions.hexToRGBString "," config.colorScheme.palette.base00;
      c9 = inputs.nix-colors.lib-core.conversions.hexToRGBString "," config.colorScheme.palette.base0C;
      cF = inputs.nix-colors.lib-core.conversions.hexToRGBString "," config.colorScheme.palette.base06;
    in ''
#window {
    background-color: rgba(${c0}, 0.5);
    margin-right: 200px;
}

#text {
    color: rgba(${cF}, 1);
}

#input {
    color: #999999;
    border: 1px solid rgba(100, 100, 100, 1);
    border-radius: 10px;

    margin-left: 100px;
    margin-right: 100px;
    margin-top: 10px;
    margin-bottom: 20px;

    box-shadow: none;
    background-color: rgba(${c0}, 0.9);
}

#input:focus {
    color: #999999;
    border: 1px solid rgba(${c9}, 1);

    margin-left: 10px;
    margin-right: 10px;
    margin-top: 10px;
    margin-bottom: 20px;

    box-shadow: none;
    background-color: rgba(${c0}, 0.9);
}

#entry {
    font-family: JetBrainsMono;
    border-radius: 10px;
    margin: 5px;
    margin-right: 20px;
    margin-left: 20px;
    padding-left: 10px;
}

#entry:focus, #entry:selected {
    background: rgba(${c9}, 0.5);
    border: 1px solid rgba(${c9}, 1);
}
    '';
  };
}
