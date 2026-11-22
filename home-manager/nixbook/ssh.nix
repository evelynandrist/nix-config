{ config, lib, pkgs, ... }:
let
  authorizedKeys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOmZZyhqDHkirDFXCoT9sw008Mj0GwlD9qv9M51MONQKAAAAC3NzaDp5dWJpa2V5 yubikey-main"
    # The agent on dellserver (nixos/dellserver/agent.nix), for iOS builds.
    # It logs in as Evelyn; by rule it writes only under ~/t3 (its `mac`
    # tool), Evelyn's own repo folders are never written to.
    "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID4Bn41L9SvJwW6xRdnysYEwDuhd9gG/5YD1WOGyuAvU agent@dellserver"
  ];

  keysFile = pkgs.writeText "authorized_keys"
    (lib.concatMapStrings (k: k + "\n") authorizedKeys);
in
{
  # Deliberately NOT home.file: that would leave a symlink into the store, and
  # sshd's StrictModes resolves the link and checks the *target's* ownership
  # and permissions. Root-owned 0444 store paths usually pass, but "usually"
  # is a bad bet on a machine with no working display to fix it from. Copying
  # the file in at 0600 removes the question.
  home.activation.authorizedKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.ssh"
    run chmod 700 "$HOME/.ssh"
    run install -m600 ${keysFile} "$HOME/.ssh/authorized_keys"
  '';
}
