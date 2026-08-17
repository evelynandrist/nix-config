{ config, lib, ... }:
let
  # Bootstrap ordering: sops.age.generateKey creates the key *during*
  # activation, but the recipient cannot be in .sops.yaml until the key
  # exists, so declaring secrets on the first switch fails activation.
  #
  #   1. `darwin-rebuild switch` with this false — generates the age key.
  #   2. `age-keygen -y ~/.config/sops/age/keys.txt`, add the recipient to
  #      .sops.yaml, create secrets/nixbook.yaml.
  #   3. Flip this to true and switch again.
  #
  # On a machine with a broken display, walking into that loop is expensive,
  # hence the explicit flag rather than a comment.
  bootstrapped = true;
in
{
  sops = {
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = true;
    };
  } // lib.optionalAttrs bootstrapped {
    defaultSopsFile = ../../secrets/nixbook.yaml;
    defaultSopsFormat = "yaml";

    secrets."nixbook/build_keychain_password" = {
      path = "${config.userConfig.secretsDir}/nixbook/build_keychain_password";
      mode = "0400";
    };
  };
}
