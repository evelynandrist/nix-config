{ config, lib, pkgs, inputs, ... }: {
  programs.himalaya.enable = true;

  accounts.email.accounts."evelyn" = {
    address = "evelyn@andrist.dev";
    himalaya = {
      enable = true;
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
    gpg = {
      key = "0xE264A88262066B52";
      signByDefault = true;
    };
  };
}
