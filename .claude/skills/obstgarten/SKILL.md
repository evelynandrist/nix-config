---
name: obstgarten
description: How to inspect, debug and change the "obstgarten" Minecraft server (Paper + Geyser) on nixserver - SSH access, console commands, logs, file layout, and the deploy workflow. Use whenever working on the Minecraft server, its plugins, or nixos/nixserver/minecraft.nix.
---

# Working on the obstgarten Minecraft server

The family survival server: Paper with Geyser/Floodgate, so Java, Xbox, Switch
and phones can play together. Config lives in `nixos/nixserver/minecraft.nix`
(read the comments there first, they explain most decisions). It runs on
nixserver via nix-minecraft (`nixos/nixserver/nix-minecraft.nix`).

## Access

- Run every command as `ssh nixserver '<command>'`. That logs in as `entity`,
  with the YubiKey key, over a ControlMaster connection that lasts 4h.
- Before starting, run `ssh -O check nixserver`. If no master is running, don't
  try to connect yourself: without a TTY the YubiKey prompt fails, and repeated
  attempts hit MaxAuthTries. Ask the user to run `ssh nixserver true` **in a
  normal terminal** (not `!` in Claude Code) and touch the key, then continue.
- `entity` is in the `minecraft` group. That is enough for the console socket,
  the data dir, `journalctl` and `systemctl status`. **There is no sudo**:
  never run sudo or ask for the password. If something really needs root, tell
  the user the exact command and let them run it.

## Paths and units

| What | Where |
| --- | --- |
| Data dir | `/persist/data/minecraft-servers/obstgarten` |
| Server log | `<data dir>/logs/latest.log` (older logs are `logs/*.log.gz`) |
| Console socket | `/run/minecraft/obstgarten.sock` (tmux) |
| Service | `minecraft-server-obstgarten.service` |
| Start-up output (plugin downloads, config patching) | `journalctl -u minecraft-server-obstgarten` |
| Nightly restart | `minecraft-obstgarten-nightly-restart.timer`, 04:30 Europe/Zurich |
| Backups | `restic-backups-minecraft.timer`, hourly. `/persist/backups/minecraft` (root only) |
| Map | https://mc.qwt.ch (BlueMap, behind nginx) |

## Console

tmux may not be on PATH yet (it was added to systemPackages on 2026-11-06).
This line works either way:

```sh
ssh nixserver '
  tm=$(command -v tmux || ls -d /nix/store/*-tmux-*/bin/tmux | head -1)
  s=/run/minecraft/obstgarten.sock
  $tm -S $s send-keys C-u "list" Enter
  sleep 1
  $tm -S $s capture-pane -p -S -40 | grep -v "^$" | tail -n 15
'
```

- No leading `/` on console commands. `C-u` clears any half-typed line first.
- Reading the answer from `latest.log` (grep for the timestamp) is often
  cleaner than `capture-pane`.
- Never attach interactively (`tmux attach`). That blocks the shell.
- **Read-only** commands (`list`, `tps`, `mspt`, `spark ...`, `lp ... info`,
  `whitelist list`, `fwhitelist list`, `co lookup ...`, `version`, `plugins`)
  are fine to run any time.
- **Ask first** before anything that affects players or the world: `stop`,
  `restart`, kick/ban, gamerule/difficulty changes, `whitelist add/remove`,
  `op`, teleporting or giving items, `co rollback/restore`, `chunky` jobs,
  `/graves purge|cleanup`, `bluemap purge`. Before asking about anything that
  disrupts play, check who is online with `list`.
- Don't run `save-off`. The restic backup hook toggles saving itself, and
  leaving it off risks losing progress.

## Where to change things

Some files get overwritten on every start, so editing them on the server
directly gets lost:

- **Nix-managed (change in the repo):** `server.properties`, `ops.json`,
  `plugins/BlueMap/core.conf` (nix-minecraft `files`), and the keys that
  `patchConfigs` sets in Geyser, Essentials, Chunky and the BlueMap map configs.
  Plugin jars are downloaded again on every start by `updatePlugins`, so add or
  remove plugins in that script.
- **Managed in-game or on the server:** the whitelist (`whitelist add <java
  name>`, `fwhitelist add <gamertag>`), LuckPerms data, and any plugin config
  key that `patchConfigs` doesn't touch. You may edit such config files over
  SSH (the group has write access), but say exactly what you changed and why.
  If the change should survive a reinstall, move it into `patchConfigs`
  instead.
- Most plugin configs only take effect after a restart, or after the plugin's
  own reload command, if it has a reliable one.

## Deploying repo changes

1. Edit the repo and check the build with `nix eval`, or
   `nix build .#nixosConfigurations.nixserver.config.system.build.toplevel`.
2. Show the user the diff. **The user deploys**: it needs their sudo password,
   and they want to review system changes before they go live. Don't commit
   unless asked.
3. After the deploy, check `systemctl status`, the start-up journal and
   `latest.log` (look for `Done (` and plugin errors).

A deploy that changes the server restarts it and kicks everyone, so mention
when players are online.

## Debugging checklist

- Bedrock players can't connect: look for Geyser, NetherNet and MCXboxBroadcast
  lines in `latest.log`. Check whether the nightly Geyser download worked
  (journal at 04:30). Also check UDP/TCP 19132 and the `LD_LIBRARY_PATH` /
  `AF_NETLINK` notes in `minecraft.nix`.
- Lag: `tps`, `mspt`, `spark profiler start` / `spark profiler stop` (this
  posts a link to the spark viewer). Check the heap with `spark heapsummary`
  first.
- Grief or missing items: `co lookup` / `co inspect` (CoreProtect) and GravesX.
  Rollbacks only with approval.
- Plugin warnings at start-up: `grep -E "WARN|ERROR" logs/latest.log`, and the
  start-pre lines in the journal ("keeping the existing file" means a download
  failed).
