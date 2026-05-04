{ config, lib, pkgs, inputs, ... }: {
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    # languagePacks = ["en-US"];
    policies = import ./policies-config.nix;

    profiles.${config.userConfig.username} = rec {
      settings = {
	"zen.workspaces.continue-where-left-off" = true;
	"zen.welcome-screen.seen" = true;
	"zen.view.use-single-toolbar" = false;
	"zen.view.window.scheme" = 0; # dark mode
      };

 #      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
	# bitwarden
	# ublock-origin
	# vimium-c
 #      ];

      mods = [
      ];

      search = import ./search-config.nix {inherit pkgs;};

    };
  };

  # programs.zen-browser = {
  #   enable = true;
  #   setAsDefaultBrowser = true;
  #
  #   policies = {
  #     DisableAppUpdate = true;
  #     DisableTelemetry = true;
  #     DisablePocket = true;
  #   };
  #
  #   profiles.default = {
  #     settings = {
  #       "zen.workspaces.continue-where-left-off" = true;
  #       "zen.view.compact.hide-tabbar" = true;
  #       "zen.urlbar.behavior" = "float";
  #     };
  #
  #     mods = [
  #       "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
  #       "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
  #     ];
  #
  #     search = {
  #       force = true;
  #       default = "ddg";
  #     };
  #
  #     bookmarks = {
  #       force = true;
  #       settings = [
  #         {
  #           name = "Quick Links";
  #           toolbar = true;
  #           bookmarks = [
  #             {
  #               name = "GittHub";
  #               url = "https://github.com";
  #             }
  #           ];
  #         }
  #       ];
  #     };
  #
  #     containersForce = true; # Delete containers not declared here
  #     containers = {
  #       Work = {
  #         color = "blue";
  #         icon = "briefcase";
  #         id = 1;
  #       };
  #     };
  #
  #     spacesForce = true; # Delete spaces not declared here
  #     spaces = {
  #       "General" = {
  #         id = "c6de089c-410d-4206-961d-ab11f988d40a";
  #         position = 1000;
  #         icon = "🏠";
  #       };
  #       "Work" = {
  #         id = "cdd10fab-4fc5-494b-9041-325e5759195b";
  #         position = 2000;
  #         icon = "💼";
  #         container = 1;
  #       };
  #     };
  #
  #     pinsForce = true; # Delete pins not declared here
  #     pins = {
  #       "GitHub" = {
  #         id = "48e8a119-5a14-4826-9545-91c8e8dd3bf6";
  #         url = "https://github.com";
  #         position = 101;
  #       };
  #     };
  #
  #     keyboardShortcutsVersion = 17;
  #     keyboardShortcuts = [
  #       {
  #         id = "zen-compact-mode-toggle";
  #         key = "c";
  #         modifiers = {
  #           control = true;
  #           alt = true;
  #         };
  #       }
  #       {
  #         id = "key_quitApplication";
  #         disabled = true;
  #       }
  #     ];
  #   };
  # };
}
