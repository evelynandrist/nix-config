# The agent user on dellserver (nixos/dellserver/agent.nix). Not based on
# ../common/home.nix: that one signs commits with Evelyn's gpg key and logs
# gh in, neither of which the agent may have. Only the zsh setup is shared,
# so T3's terminal looks like Evelyn's.
{ ... }: {
  imports = [ ../common/zsh.nix ];

  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "26.11";

  programs.git = {
    enable = true;
    settings.user = {
      email = "evelyn@andrist.dev";
      name = "Evelyn Andrist";
    };
    # the agent has no signing key; main is protected by requiring a pull
    # request, not by signatures
    signing.signByDefault = false;
  };
}
