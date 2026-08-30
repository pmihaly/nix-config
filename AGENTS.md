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
- SSH auth is key-based as user `misi`: `~/.ssh/id_skylake_rescue` (authorized for `misi` on skylake). No password for the SSH login itself.
- `user = "root"` + `interactiveSudo = true`: deploy-rs rewrites the remote command to `sudo -S -p ""` and prompts for the sudo password locally via rpassword, which reads from `/dev/tty`. `scripts/deploy-skylake.sh` runs deploy under util-linux `script` (pty) and feeds the gitignored `machines/skylake/sudo-password` in up front; `script -e` propagates the exit code. Known cosmetic quirk: the password is echoed once at the top (local-terminal-only).
- On activation failure, deploy-rs revokes the deploy and rolls back to the previous generation.

### Hermes and deployment

Hermes on skylake edits the `/home/misi/.nix-config` checkout and has **one ssh channel only**: `git push`/`git fetch` to `git@github.com:pmihaly/nix-config`, authenticated by the `server/hermes-github-ssh` agenix secret + her `~/.ssh/config` (both from `modules/nixos/hermes-agent`). She cannot reach aesop over ssh — the old forced-command `hermes-deploy` channel, its key copies, and the gitops auto-deploy timer are all gone. Deploying skylake is a human `make skylake` on aesop that builds and activates whatever is in the local checkout (aesop's — the machine doing the deploy).

Hermes CAN apply her own skylake config once deployed (machines/skylake):

```
sudo /run/current-system/sw/bin/systemctl start hermes-config-apply.service
```

That is her ONLY root capability — a passwordless sudo rule (`security.sudo.extraRules`) lets her start two fixed root oneshot services (`hermes-config-apply`, and `hermes-config-apply-rollback` for `nixos-rebuild switch --rollback`); no arbitrary command. The apply service runs `nixos-rebuild switch --flake . --hostname skylake` from `/home/misi/.nix-config`, so she should `git pull --ff-only origin vibecode` first. Logs: `journalctl -u hermes-config-apply`.

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
