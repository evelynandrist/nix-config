{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.simple-nixos-mailserver.nixosModule ];

  sops.secrets = {
    "mailserver/logins/evelyn" = { };
  };

  mailserver.stateVersion = 3;

  mailserver = {
    enable = true;
    fqdn = "mail.andrist.dev";
    domains = [ "andrist.dev" ];
    storage.path = "/persist/data/mailserver/vmail";
    dkim.keyDirectory = "/persist/data/mailserver/dkim";
    x509.useACMEHost = config.mailserver.fqdn;
    enableImap = true;

    accounts = {
      "evelyn@andrist.dev" = {
	hashedPasswordFile = config.sops.secrets."mailserver/logins/evelyn".path;
	aliases = [ "postmaster@andrist.dev" "felix@andrist.dev" ];
      };
    };
  };

  services.roundcube = {
    enable = true;
    # this is the url of the vhost, not necessarily the same as the fqdn of
    # the mailserver
    hostName = config.mailserver.fqdn;
    extraConfig = ''
      $config['smtp_host'] = "ssl://${config.mailserver.fqdn}:465";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
    '';
  };

  # increase greylist threshold to let mails from openai.com through
  services.rspamd.extraConfig = ''
    actions {
      reject = 15; # Reject message when reaching this score
      greylist = 9; # Apply greylisting when reaching this score, default is 4
      add_header = 6; # Add header when reaching this score
    }
  '';
}
