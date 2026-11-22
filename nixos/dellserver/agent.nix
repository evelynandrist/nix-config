# Agent workspace: T3 Code with Claude Code, run as the user `agent`.
#
# Reached as https://t3.internal.qwt.ch through nginx on packardserver (LAN
# and VPN only). Nothing else may connect: the port is open for
# packardserver alone. Every browser and phone pairs once, sessions last 30
# days (t3code 0.1.8).
#
# State, all in /home/agent (own btrfs subvolume: kept across reboots, not
# in the backup except where noted):
#   .t3/userdata/   T3's thread database, logs and secrets.
#                   settings.json and keybindings.json are in the nightly
#                   restic backup, nothing else (transcripts are not).
#   .claude/        Claude Code's login and settings. skills/ is in the
#                   backup, except synced/ (downloaded by Claude Code).
#   .ssh/id_ed25519 the agent's own key, made by agent-ssh-key on first boot.
#                   Added to Evelyn's GitHub and Bitbucket: it can push
#                   branches to every repo she can reach, but not to
#                   nix-config main (changes only through a pull request,
#                   and merging one needs a GitHub login). It also logs in
#                   to the nixbook as Evelyn (home-manager/nixbook/ssh.nix).
#   repos/          clones.  worktrees/  T3's worktrees (set in T3 settings).
#   .t3/tools/      the headless Chrome behind T3's browser (the agent's
#                   preview_* tools). T3 downloads it itself, pinned by
#                   version and hash, so it only changes with t3code.
#   .t3/userdata/server-browser/profiles/
#                   that browser's cookies. A tab can be taken over from the
#                   T3 app: whatever is signed in to there, the agent has too.
#
# iOS builds on the nixbook: `mac sync`, `mac run nix/build.sh`, `mac clean`
# (home-manager/dellserver/agent.nix). The agent logs in there as Evelyn and
# writes only under ~/t3.
#
# Commits are authored as Evelyn, unsigned (home-manager/dellserver/agent.nix).
# No GitHub token may ever be readable by this user: setting the test-deploy
# label and merging a pull request each need one. For the same reason GitHub Actions is switched off for
# nix-config and must stay off: a workflow on a pushed branch gets such a
# token (see flake-update.nix).
#
# T3 restarts with the nightly upgrade; a running turn waits for Resume.
#
# Two timers start threads by themselves, with `t3 thread start`: the weekly
# bump (flake-update.nix) and the check for failed units after the nightly
# upgrade (upgrade-check.nix).
#
# Manage:
#   ssh agent@dellserver
#   sudo systemctl restart t3code;  journalctl -u t3code
#   sudo -u agent claude auth login                       (once)
#   sudo -u agent cat /home/agent/.ssh/id_ed25519.pub     (for GitHub/Bitbucket)
#   sudo -u agent t3 auth pairing create --base-url https://t3.internal.qwt.ch
#   sudo -u agent t3 auth session list|revoke
#   sudo -u agent t3 connect link --publish-only --headless   (once, phone pushes)
#     then restart t3code; check with `t3 connect status`, turn publishing
#     on with `t3 connect publish`. Push notifications work this way.
#     The Android live activity widget does not (yet): the phone app links
#     through its own connection, and T3 signs that link proof only for
#     loopback requests without X-Forwarded-* headers, never through nginx.
#     Turning it on needs T3's managed tunnel or an upstream change.
#
# Connect settings in the web UI do not work: the nixpkgs web client is
# built without Connect's public configuration (the wrapper below only
# fixes the server and CLI). Use the CLI.
#
# Later:
#   - Test-deploying the weekly bump before the merge as the rule. Today
#     only when Evelyn asks for it in the bump's thread.
#   - Restart T3 only when idle, if the nightly restart interrupts real work.
#   - Skills (planning), Azure and database access.
#   - PRs from the T3 app (enableGitHub plus a token): needs a deploy
#     approval that a token cannot give, instead of the test-deploy label.
#   - If Claude turns fail without a user session, switch to a user unit with
#     linger, as upstream does.
{ pkgs, ... }:
let
  port = 3773;
  home = "/home/agent";
  userdata = "${home}/.t3/userdata";
  t3codeBase = pkgs.t3code.override {
    enableClaude = true;
    enableCodex = false;
    # gh would let T3 open PRs from the app, but only with a token, and any
    # token that can open PRs can also set the test-deploy label. Enable it
    # only once deploy approval no longer rests on that label (see Later).
    enableGitHub = false;
  };
  # The nixpkgs build lacks T3 Connect's public configuration, which
  # upstream bakes into its releases; without it `t3 connect` does not exist
  # and nothing is pushed to the phone. The values are public by design
  # (Clerk publishable key, OAuth client id), copied from the official
  # v0.1.8 linux-x64 release. Check them again when t3code is updated.
  t3code = pkgs.symlinkJoin {
    name = "t3code-connect-${t3codeBase.version}";
    paths = [ t3codeBase ];
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    postBuild = ''
      wrapProgram $out/bin/t3 \
        --set-default T3CODE_RELAY_URL https://relay.t3.codes \
        --set-default T3CODE_CLERK_PUBLISHABLE_KEY pk_live_Y2xlcmsudDMuY29kZXMk \
        --set-default T3CODE_CLERK_CLI_OAUTH_CLIENT_ID hzxSgY2cH10sDU2r
    '';
  };
in {
  # The user itself, its key on the other hosts and its sudo rules:
  # ../common/agent-access.nix
  users.users.agent = {
    inherit home;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOmZZyhqDHkirDFXCoT9sw008Mj0GwlD9qv9M51MONQKAAAAC3NzaDp5dWJpa2V5 yubikey-main"
    ];
    # claude-code too: t3code puts it only on its own wrapper's PATH, and
    # `claude auth login` is run in a shell
    packages = [ t3code pkgs.claude-code ];
  };

  home-manager.users.agent = import ../../home-manager/dellserver/agent.nix;

  # The agent pushes without anyone answering a host key prompt.
  programs.ssh.knownHosts = {
    "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    "bitbucket.org".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO";
    # for test deploys (../common/agent-access.nix)
    "packardserver".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+DM5/muda4czqL7luaLqVfuS67fb9sYZiw6bXbHp+V";
    "nixserver.qwt.ch".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINeSBKfQ3vO2GZbGQFMzFC5G5HVf2D5E04eQmkaoPgUs";
    # iOS builds (`mac`, home-manager/dellserver/agent.nix)
    "nixbook.internal.qwt.ch".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9UeWoyTfsPkpgv8dyCF5icOLdac7+I528tlLxQkCkp";
  };

  systemd.services.agent-ssh-key = {
    description = "Make the agent's ssh key if it has none";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "agent";
      Group = "agent";
    };
    script = ''
      if [ ! -e ${home}/.ssh/id_ed25519 ]; then
        mkdir -p -m 700 ${home}/.ssh
        ssh-keygen -t ed25519 -N "" -C agent@dellserver -f ${home}/.ssh/id_ed25519
      fi
    '';
  };

  # A system service, not a user unit: without XDG_RUNTIME_DIR T3 does not
  # wrap agents in systemd-run --user scopes, which fail silently without a
  # user session.
  systemd.services.t3code = {
    description = "T3 Code server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "agent-ssh-key.service" ];
    wants = [ "network-online.target" "agent-ssh-key.service" ];
    # nix, ssh, rsync and sudo for the agent's tools
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    environment = {
      HOME = home;
      # T3's terminal; systemd does not set SHELL for system services
      SHELL = "${pkgs.zsh}/bin/zsh";
      T3CODE_TELEMETRY_ENABLED = "false";
    };
    serviceConfig = {
      User = "agent";
      Group = "agent";
      WorkingDirectory = home;
      ExecStart = "${t3code}/bin/t3 serve --host 0.0.0.0 --port ${toString port}";
      Restart = "on-failure";
    };
  };

  # T3's browser: its Chrome is a plain Linux binary and finds these through
  # nix-ld (`t3 browser setup`, which the journal suggests, only knows apt).
  # Chrome's own sandbox works as it is; never set
  # T3CODE_SERVER_BROWSER_SANDBOX=0.
  programs.nix-ld.libraries = with pkgs; [
    glib nspr nss at-spi2-core dbus expat alsa-lib libgbm libxkbcommon
    libx11 libxcb libxcomposite libxdamage libxext libxfixes libxrandr
  ];
  # Without fonts every page renders in one fallback face.
  fonts.enableDefaultPackages = true;

  # The two settings files and the skills written by hand. Listed only when
  # they exist: a missing path makes restic fail the whole run.
  services.restic.backups.truenas.dynamicFilesFrom = ''
    for f in ${userdata}/settings.json ${userdata}/keybindings.json ${home}/.claude/skills/*; do
      case "$f" in */synced) continue ;; esac
      [ -e "$f" ] && echo "$f"
    done
    true
  '';

  # allowedTCPPorts cannot restrict by source, as in paperless.nix.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s packardserver.internal.qwt.ch --dport ${toString port} -j nixos-fw-accept
  '';
}
