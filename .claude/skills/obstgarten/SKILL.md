---
name: obstgarten
description: Rules and gotchas for working on the "obstgarten" Minecraft server (Paper + Geyser) on nixserver - console access, what needs asking first, which files are overwritten on start. Use whenever working on the Minecraft server, its plugins, or nixos/nixserver/minecraft.nix.
---

# Working on the obstgarten Minecraft server

The family survival server. Everything about how it is built is in
`nixos/nixserver/minecraft.nix`; read its comments first. This file only
holds what the code cannot tell you.

## Access

- From dellserver: `ssh nixserver.qwt.ch '<command>'`, as `agent`.
- From nixpad: `ssh nixserver '<command>'`, as Evelyn's user with the
  YubiKey. Run `ssh -O check nixserver` first; if no connection is open,
  ask her to run `ssh nixserver true` in a normal terminal. Don't retry
  yourself, the touch prompt fails without a TTY.
- Both users are in the group `minecraft`: the console, the data dir
  (`/persist/data/minecraft-servers/obstgarten`), the journal and
  `systemctl status` work. No sudo. If something needs root, give Evelyn
  the exact command.

## Console

```sh
ssh nixserver.qwt.ch '
  s=/run/minecraft/obstgarten.sock
  tmux -S $s send-keys C-u "list" Enter
  sleep 1
  tmux -S $s capture-pane -p -S -40 | grep -v "^$" | tail -n 15
'
```

- No leading `/`. `C-u` clears a half-typed line.
- Never `tmux attach`: it blocks the shell.
- The answer is also in `logs/latest.log`, often cleaner than the pane.

The group gives the full console. What keeps the family's world safe is
this list, so follow it:

- **Any time**: commands that only read (`list`, `tps`, `mspt`, `spark ...`,
  `lp ... info`, `whitelist list`, `fwhitelist list`, `co lookup ...`,
  `version`, `plugins`).
- **Ask first**: anything that affects players or the world. `stop`,
  `restart`, kick/ban, gamerules and difficulty, `whitelist add/remove`,
  `op`, teleporting or giving items, `co rollback/restore`, `chunky` jobs,
  `graves purge|cleanup`, `bluemap purge`. Check who is online with `list`
  before you ask.
- **Never** `save-off`: the backup toggles saving itself, and leaving it
  off loses progress.
- Nobody is op on purpose; the Java account is played by a family member.

## Changing things

- Files written by nix are overwritten on every start: `server.properties`,
  `plugins/BlueMap/core.conf`, and every key `patchConfigs` sets. Plugin
  jars are downloaded again on every start by `updatePlugins`. Change these
  in the repo.
- Whitelist, ops, LuckPerms data and config keys `patchConfigs` does not
  touch live on the server. You may edit such config files (ask first, say
  exactly what changed); if it should survive a reinstall, put it into
  `patchConfigs` instead.
- Most plugin configs only apply after a restart.
- Repo changes go out with the skill `deploy`. A deploy that changes the
  server restarts it and kicks everyone.

## When something is wrong

- Start-up (plugin downloads, config patching) is in
  `journalctl -u minecraft-server-obstgarten`; "keeping the existing file"
  means a download failed. Game output is in `logs/latest.log`: look for
  `Done (` and `WARN|ERROR`.
- Bedrock players can't connect: Geyser, NetherNet and MCXboxBroadcast
  lines in `latest.log`, then whether the 04:30 Geyser download worked.
- Lag: `tps`, `mspt`, `spark heapsummary`, then `spark profiler start` /
  `stop`.
- Grief or missing items: `co lookup`, `co inspect`, GravesX. Rollbacks
  only with approval.
