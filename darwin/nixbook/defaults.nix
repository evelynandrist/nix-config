{ ... }: {
  system.defaults = {
    # needed for aerospace
    spaces.spans-displays = true;
    dock.mru-spaces = false;

    dock = {
      autohide = true;
      show-recents = false;
      # disable hot corners because of deskflow
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
    };

    NSGlobalDomain = {
      # disable press-and-hold shortcut for accented characters, would break hjkl navigation
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      AppleInterfaceStyle = "Dark";
      "com.apple.swipescrolldirection" = true; # natural scroll
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    screencapture.location = "~/Screenshots";

    loginwindow.GuestEnabled = false;
  };

  # runs on ac in clamshell mode, so we don't want sleep
  power.sleep = {
    computer = "never";
    harddisk = "never";
    # display may sleep
    display = 30;
  };

  power.restartAfterPowerFailure = true;
}
