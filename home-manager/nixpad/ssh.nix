{ config, lib, pkgs, ... }: {
  programs.ssh = {
    enable = true;

    # The module's implicit `Host *` defaults are on their way out and warn if
    # left enabled, so they are spelled out below instead.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      nixbook = {
        # macOS advertises itself over Bonjour; nixpad resolves that through
        # avahi + nssmdns4, enabled in nixos/nixpad/configuration.nix.
        HostName = "nixbook.local";
        User = config.userConfig.username;

        # SSH uses the yubikey, so *every* connection costs a physical touch.
	# Multiplexing decreases the number of touches by a lot.
        ControlMaster = "auto";
        ControlPath = "~/.ssh/cm-%r@%h:%p";
        ControlPersist = "10m";

        # A clamshell Mac on AC should not be dropping connections, but keep
        # the session alive across brief network blips mid-build.
        ServerAliveInterval = 30;
        ServerAliveCountMax = 6;
      };

      "140.238.214.181" = {
	 IdentityFile = "/home/evelyn/nixpad_backup/ssh-key-2023-01-27.key";
      };
    };
  };
}
