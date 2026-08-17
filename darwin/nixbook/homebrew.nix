{ config, inputs, ... }: {
  # Homebrew, in two halves:
  #   nix-homebrew owns the *installation* (prefix, taps, ownership)
  #   the nix-darwin `homebrew` module declares what is *installed into* it

  nix-homebrew = {
    enable = true;
    user = config.userConfig.username;
    # apple silicon only
    enableRosetta = false;
    mutableTaps = false; # declaritive taps
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "deskflow/homebrew-tap" = inputs.homebrew-deskflow;
    };
    # Take over an existing imperative install rather than refusing to start.
    autoMigrate = true;
  };

  homebrew = {
    enable = true;

    taps = builtins.attrNames config.nix-homebrew.taps;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # TODO: change to "zap" later
      cleanup = "uninstall";
    };

    casks = [
      "deskflow/tap/deskflow"
    ];

    masApps = {
      # needs sign-in to app store
      Xcode = 497799835;
    };
  };
}
