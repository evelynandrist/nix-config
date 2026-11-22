---
name: deploy
description: Get a nix-config change onto a host - build, push a branch, hand Evelyn the link that opens the pull request with the test-deploy label, test-deploy it, check the result. Use whenever a change in this repo should be tried on or shipped to dellserver, packardserver or nixserver.
---

# Deploying a nix-config change

For sessions running as `agent` on dellserver. The agent has no GitHub
login: Evelyn opens the pull request, sets the label and merges. What the
agent may do on a host is in `nixos/common/agent-access.nix`.

On nixpad there is no such loop: show Evelyn the diff, she deploys.

## Steps

1. **Build** every host the change touches:

   ```sh
   nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel
   ```

2. **Show Evelyn the diff** and ask before committing and pushing. Then
   push the branch: `git push -u origin <branch>`.

3. **Give her this link.** It opens the pull request form with the label
   filled in, so creating the PR is also her approval of the test deploy:

   ```
   https://github.com/evelynandrist/nix-config/compare/main...<branch>?quick_pull=1&labels=test-deploy
   ```

   Say which hosts you want to test-deploy on, and whether that restarts
   something people use (see below). If the label did not arrive (the
   phone app may drop it), she sets it by hand.

4. **Find the PR number** once she says it is open:

   ```sh
   curl -fsS 'https://api.github.com/repos/evelynandrist/nix-config/pulls?head=evelynandrist:<branch>' \
     | jq -r '.[] | "\(.number) \([.labels[].name] | join(","))"'
   ```

   No login, so 60 requests an hour, and the script on the host spends one
   per run. Don't poll.

5. **Test-deploy.**

   ```sh
   ssh <host> sudo agent-test-deploy <number>     # packardserver, nixserver.qwt.ch
   sudo agent-test-deploy <number>                # dellserver itself
   ```

   It deploys the head commit of the PR with `nixos-rebuild test`: active
   now, but not the boot default.

6. **Check**: `systemctl status <unit>`, `journalctl -u <unit> -b`, and
   `systemctl --failed`. The agent can read all of these without sudo.

7. Fix, push, run step 5 again. The label approves the branch, so later
   commits need no new approval.

8. **Finish.** Tell Evelyn the PR is ready to merge. A merged PR reaches
   every host at 04:00. If the change is dropped instead, return the host
   to main and ask her to remove the label:

   ```sh
   ssh <host> sudo systemctl start nixos-upgrade.service
   ```

## What a test deploy restarts

- **dellserver**: a change to the `t3code` unit restarts T3, and with it
  this session. The turn stops and waits for Resume. Tell Evelyn before,
  and say in the same message what you will check afterwards.
- **nixserver**: a change to the Minecraft server restarts it and kicks
  everyone. Check who is online first (skill `obstgarten`) and ask.
- A reboot or the 04:00 upgrade returns a test-deployed host to main. An
  unmerged change is gone the next morning.

## Not possible from here

- nixpad and the nixbook: Evelyn deploys those herself, after the merge.
  The switch needs her password. On the Mac, in her checkout of this repo:
  `sudo darwin-rebuild switch --flake .#nixbook`
- Anything with sops secrets or other sudo commands: give her the exact
  command.
