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

  # Per-project toolchains without a manual `nix develop` on every ssh session.
  # nix-direnv keeps the dev shell cached and GC-rooted, so re-entering a project
  # directory is instant instead of re-evaluating the flake.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
