## Repository Structure

- `flake.nix` — root flake, defines all inputs (home-manager, darwin, agenix, disko, stylix, nixvim, impermanence, nix-gaming, etc.)
- `machines/<machine>/default.nix` — per-machine configuration, imports use-cases
- `use-cases/<domain>/default.nix` — feature domain grouping (gui, server, dev, gaming, music-production, nix, shell)
- `use-cases/default.nix` — aggregates all use-case domains
- `modules/` and `modules-v2/` — low-level NixOS and Home Manager modules imported by use-cases

## Machines

- `aesop` — NixOS desktop, imports both `modules/nixos` and `modules-v2/nixos`
- `skylake` — NixOS server
- `work` — Darwin/macOS, reads `workvars.toml` from `/Users/${vars.username}/.nix-config/machines/work/workvars.toml`, sets `ids.uids.nixbld = 350`

## Key Patterns

- Machine configs use a `vars` attribute for dynamic settings: `vars.persistDir`, `vars.username`, `vars.domainName`, `vars.storage`
- Secrets managed via `agenix`
- Deployment handled via `deploy-rs`

## Commands

- Format: `nix fmt`
- Update all inputs: `make update` (runs `./update.nu`; excludes `finances` from parallel lock updates)
- Update finances input only: `make update-finances`
- Deploy skylake server: `make skylake` (runs `./scripts/deploy-skylake.sh` — wraps `deploy -s .#skylake` and auto-feeds the sudo password; see Deploying Skylake below)
- Switch aesop locally: `make aesop` (runs `./scripts/switch-aesop.sh` — wraps `sudo nixos-rebuild switch --flake .#aesop` and auto-feeds the password via `sudo -S` from the gitignored `machines/aesop/sudo-password`, same local-secrets policy as skylake's)
- Build aesop (test Nix changes): `nix build .#nixosConfigurations.aesop.config.system.build.toplevel`

## Deploying Skylake

`make skylake` is fully wired via `deploy.nodes.skylake` in `flake.nix` and works unattended (no TTY, no manual typing) — it runs `./scripts/deploy-skylake.sh`, which wraps `deploy -s .#skylake` and auto-answers the sudo prompt:

```
make skylake
# → (sudo for 100.69.8.15) Password:   (auto-filled from machines/skylake/sudo-password)
```

How it works:

- Connects to the Tailscale IP `100.69.8.15`. Port 22 on the public Hetzner IP (`157.180.77.226`) is firewalled (only nginx 80/443 is public), and `~/.ssh/config` `Host skylake` still points at that blocked IP — so a bare `ssh root@skylake` from aesop times out. The flake config overrides the hostname and passes the key explicitly.
- SSH auth is key-based as user `misi`: `~/.ssh/id_skylake_rescue` (authorized for `misi` on skylake). No password for the SSH login itself. `sshOpts` passes **both** that and the hermes-deploy copy at `/var/lib/hermes-deploy/.ssh/id_skylake_rescue` — whichever user runs `deploy` must be able to read a key, because without one ssh falls back to the password prompt, which eats the pty-fed sudo password and hangs the deploy.
- `user = "root"` + `interactiveSudo = true`: deploy-rs rewrites the remote command to `sudo -S -p ""` and prompts for the sudo password locally via rpassword, which reads from `/dev/tty`. That means the password cannot be fed via stdin/pipe — a plain pipe into `deploy` never reaches the prompt.
- The sudo password lives in the gitignored file `machines/skylake/sudo-password` (chmod 600, same local-secrets policy as `RESCUE.md`). `scripts/deploy-skylake.sh` runs deploy under util-linux `script` (which provides a pty) and feeds that file's content in up front: the line is queued in the pty's line discipline and consumed when rpassword opens `/dev/tty` minutes later. `script -e` propagates deploy's exit code, so `make skylake` fails correctly on activation failure.
- Known cosmetic quirk: the password is echoed once at the top of the deploy output (the pty is in echo mode until rpassword turns echo off). Local-terminal-only exposure, same as typing it by hand.
- On activation failure, deploy-rs revokes the deploy and rolls back to the previous generation.

### Deploying from skylake (hermes)

The hermes agent on skylake can deploy skylake itself — no aesop session needed. From the skylake side (as the `hermes` user, or `runuser -u hermes -- deploy-skylake` for manual testing):

```
deploy-skylake
```

What it does (all least-privilege, one restricted ssh call):

- `deploy-skylake` (on the hermes service PATH, `modules/nixos/hermes-agent`) ssh's to `hermes-deploy@aesop` with a dedicated key (`server/skylake-deploy-ssh` agenix secret, materialized at `/run/agenix/server/skylake-deploy-ssh`, hermes-owned 400).
- That key is `restrict` + `command=` only: every connection runs `scripts/hermes-deploy.sh` as a forced command — no shell, no other commands, no forwarding, no rhosts (see `machines/aesop/default.nix`).
- `scripts/hermes-deploy.sh` (runs on aesop as `hermes-deploy`) fast-forwards a dedicated deploy checkout at `/var/lib/hermes-deploy/nix-config` from the skylake checkout (`ssh://misi@100.69.8.15/home/misi/.nix-config`), ff-only — it refuses to deploy if the branches diverged. Then it copies the gitignored `machines/skylake/sudo-password` into that checkout and runs the same `scripts/deploy-skylake.sh` as `make skylake`.
- So: build happens on aesop, activation on skylake, same rollback-on-failure. Output streams back over the ssh connection. Deploys the **skylake** checkout's current `HEAD` (whatever branch hermes is on) — commit there first; uncommitted changes are not deployed.
- The main aesop checkout `/home/misi/.nix-config` is never written to by this path; hermes-deploy only reads the (world-readable) deploy script and the gitignored sudo password from it, plus the `600` key copy in its own home. The `hermes-deploy-repo` activation script self-heals this on every aesop activation: the sudo password gets `chgrp hermes-deploy` + `640`, a private `600` **copy** of `~/.ssh/id_skylake_rescue` is installed at `/var/lib/hermes-deploy/.ssh/` (the original stays `600` — ssh ignores group-readable private keys for the owner), and the traverse-only `x` ACL on `/home/misi` is re-applied (idempotent, no manual steps).
- Don't run `deploy-skylake` and `make skylake` at the same time — two concurrent deploy-rs runs against skylake will fight over the boot.

## Nix Search

- Search packages: `nix search nixpkgs <query> 2>/dev/null | grep -i "<query>"`
- Search NixOS options: `nixos-option --flake .#<machine> <query>` (e.g. `nixos-option --flake .#aesop programs.zsh.enable`)
- Search Home Manager options: `nixos-option --flake .#<machine> home-manager.users.<user>.<query>` (e.g. `nixos-option --flake .#aesop home-manager.users.misi.programs.zsh.enable`)
- Browse Home Manager options: https://home-manager-options.extranix.com/
- Browse NixOS options: https://search.nixos.org/options

## Configuration Policy

All configuration changes must be made in this repo — never edit files under `~/.config/`, `/etc/`, or other runtime paths directly. Before modifying any tool or service, look up its existing configuration in this repo first, then check the nix store if not found (e.g., `grep -r "<option>" /nix/store/…-nixos-system-*/etc/` or reading the active config from the store).

## Helpers

- `lib/nixos/default.nix` exports `mkService` (sets up nginx reverse proxy + dashboard) and `getDockerVersionFromShield`

## Server Recovery

- `machines/skylake/RESCUE.md` — full guide for entering/exiting Hetzner rescue mode, mounting disks, building and installing a new NixOS generation from the rescue environment (contains secrets, not in git)
