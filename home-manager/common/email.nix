{ config, lib, pkgs, inputs, ... }: {
  programs.himalaya.enable = true;

  accounts.email.accounts."evelyn" = {
    address = "evelyn@andrist.dev";
    himalaya = {
      enable = true;
 #      settings = {
	# default = true;
	# email = "test";
 #      };
    };
    imap = {
      host = "mail.andrist.dev";
      port = 993;
    };
    smtp = {
      host = "mail.andrist.dev";
      port = 465;
    };
    passwordCommand = "cat /run/secrets/email/logins/evelyn";
    primary = true;
    realName = "Evelyn Andrist";
    userName = "evelyn@andrist.dev";
  };
}
