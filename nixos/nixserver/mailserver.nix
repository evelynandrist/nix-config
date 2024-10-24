{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.simple-nixos-mailserver.nixosModule ];

  sops.secrets = {
    "mailserver/logins/evelyn" = { };
  };

  mailserver = {
    enable = true;
    fqdn = "mail.andrist.dev";
    domains = [ "andrist.dev" ];
    mailDirectory = "/persist/data/mailserver/vmail";
    dkimKeyDirectory = "/persist/data/mailserver/dkim";
    certificateScheme = "acme";

    loginAccounts = {
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
      # starttls needed for authentication, so the fqdn required to match
      # the certificate
      $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
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
