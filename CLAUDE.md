# nix-config

One flake for all of Evelyn's machines. The repo is public: no secrets, no
private details in files or commit messages. Secrets go through sops-nix
(`secrets/`), which a Claude session cannot edit.

## Hosts

| Host | What | Notable |
| --- | --- | --- |
| `nixpad` | laptop (Hyprland) | Evelyn's own machine |
| `dellserver` | home server | Paperless, Samba, the agent workspace (T3 Code, `nixos/dellserver/agent.nix`) |
| `packardserver` | home server | nginx for `*.internal.qwt.ch`, Home Assistant, media |
| `cranium` | NAS | ZFS pools, Immich, Jellyfin, Samba, the backup target of all hosts, the VPN |
| `nixserver` | public VPS, `nixserver.qwt.ch` | mail, Vaultwarden, the Minecraft server (skill `obstgarten`) |
| `nixbook` | Mac (nix-darwin) | iOS builds |

Per host: `nixos/<host>/` and `home-manager/<host>/`; shared parts in
`nixos/common/` and `home-manager/common/`. The file headers explain most
decisions, read them before changing a file.

## Build

    nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel
    nix eval --raw .#darwinConfigurations.nixbook.system.drvPath   # the Mac only evaluates on Linux

## Deploy

`main` only changes through a pull request, and every NixOS host switches to
`main` at 04:00 (`nixos/common/auto-upgrade.nix`). To try a change on a host
before it is merged, use the skill `deploy`. Never switch a host any other
way.

## Working rules

- Ask "shall I write this now?" before each step. Agreeing on a plan is not
  a go-ahead to write.
- Commit and push only when asked. Never push to `main`.
- Never put files into Evelyn's home directories; ask where a file belongs.
- Short, direct answers, and the simplest thing that works.
- No test scripts or test-only hooks in this repo.
- GitHub Actions is off and must stay off (`nixos/dellserver/flake-update.nix`
  says why). Add no workflows.
- `docs/` is gitignored: plans and notes there are local to one machine.
