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
    # /run/secrets on NixOS; on darwin sops runs as a home-manager module and
    # materialises elsewhere, so the directory comes from userConfig.
    passwordCommand = "cat ${config.userConfig.secretsDir}/email/logins/evelyn";
    primary = true;
    realName = "Evelyn Andrist";
    userName = "evelyn@andrist.dev";
    gpg = {
      key = "0xE264A88262066B52";
      signByDefault = true;
    };
  };
}
