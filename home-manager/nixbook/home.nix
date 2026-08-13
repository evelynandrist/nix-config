{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../common/home.nix

    inputs.sops-nix.homeManagerModules.sops

    ../../darwin/nixbook/userconfig.nix

    ./aerospace.nix
    ./ios.nix
    ./sops.nix
    ./ssh.nix
  ];

  # don't put fonts here, they're installed through nix-darwin's fonts.packages
  home.packages = with pkgs; [
    jq
    nil
    nodejs
    unzip
  ];

  home.file."Screenshots/.keep".text = "";

  programs.nh = {
    enable = true;
    flake = "/Users/${config.userConfig.username}/nix-config";
  };
}
