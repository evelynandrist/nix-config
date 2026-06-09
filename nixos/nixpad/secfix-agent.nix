{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.kolide-launcher.nixosModules.kolide-launcher ];

  environment.systemPackages = with pkgs; [
    inputs.kolide-launcher
  ];

  sops.secrets."secfix/secret" = {
    path = "/run/secrets/secfix/secret";
    owner = "nix";
  };

  services.kolide-launcher = {
    enable = true;
    kolideHostname = "m1.secfix.com:443";
    rootDirectory = "/persist/var/secfix/m1.secfix.com-443";
    enrollSecretDirectory = "/run/secrets/secfix";
    updateChannel = "nightly";
    osqueryFlags = [
      "host_identifier=specified"
      "specified_identifier=e3491575-ccca-4e76-abb1-937577e2cd17"
    ];
  };
}
