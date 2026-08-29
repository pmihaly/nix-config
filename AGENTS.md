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

`make skylake` is fully wired via `deploy.nodes.skylake` in `flake.nix` and works unattended — it runs `./scripts/deploy-skylake.sh`, a thin wrapper around `deploy -s .#skylake`:

```
make skylake
```

How it works:

- Connects to the Tailscale IP `100.69.8.15`. Port 22 on the public Hetzner IP (`157.180.77.226`) is firewalled (only nginx 80/443 is public), and `~/.ssh/config` `Host skylake` still points at that blocked IP — so a bare `ssh root@skylake` from aesop times out. The flake config overrides the hostname and passes the key explicitly.
- deploy-rs activates as **root** (`sshUser = user = "root"`): root's authorized key on skylake is the rescue key, declared in `machines/skylake/default.nix` (so it survives the tmpfs root — no impermanence surprise). No sudo prompt — hence no pty/password dance in `deploy-skylake.sh`.
- `sshOpts` passes two paths to the same rescue keypair: `~/.ssh/id_skylake_rescue` (misi, for `make skylake`) and `/run/agenix/server/skylake-activate-ssh` (the hermes-deploy user, for the auto-deploy timer). ssh tries each key it can read and skips the others.
- On activation failure, deploy-rs revokes the deploy and rolls back to the previous generation.

### Deploying from skylake (hermes) — gitops, no ssh

Hermes never ssh's to deploy. Deployment is push-based:

1. Hermes commits in the skylake checkout (`/home/misi/.nix-config`) and **pushes** to `git@github.com:pmihaly/nix-config` (branch: `vibecode`) — that push is her *only* ssh channel, authenticated by the `server/hermes-github-ssh` agenix secret + her `~/.ssh/config` (both from `modules/nixos/hermes-agent`). She cannot trigger a deploy any other way: there is no ssh channel to aesop at all anymore.
2. On aesop, the `skylake-auto-deploy` systemd timer (`machines/aesop/default.nix`, every 10 min) runs `scripts/skylake-auto-deploy.sh` as `hermes-deploy`. It fetches the **public** repo over anonymous https into the dedicated deploy checkout at `/var/lib/hermes-deploy/nix-config`, fast-forwards the local `deploy` branch (ff-only — a rewrite refuses to deploy), and — only if something moved — runs the same `scripts/deploy-skylake.sh`, which builds on aesop and activates skylake as root.
3. Nothing is copied between machines and no gitignored/`600` keys sit under `/var/lib`: the only credential on the path is the `server/skylake-activate-ssh` agenix secret, materialized by aesop itself. The old forced-command ssh channel (`hermes-deploy` authorized key, `scripts/hermes-deploy.sh`, key copies, ACLs) is gone.
4. Result visibility: the timer logs to aesop's journal (`journalctl -u skylake-auto-deploy`); on skylake, the deploy shows up as a new generation in `nixos-rebuild list-generations`.
5. Don't push (or `make skylake`) twice concurrently — the timer's `flock` skips overlapping ticks, but a human deploy racing the timer is still one deploy-rs run too many.

### gitops and secrets — keep in mind

- The aesop side needs no GitHub credentials (public repo). If the repo ever goes private, `skylake-auto-deploy.sh` needs a way to authenticate the fetch.
- The deploy only sees what is **pushed**. Committing on skylake without pushing deploys nothing — unlike the pre-gitops forced command, which fetched the skylake checkout's local `HEAD`.
- `server/skylake-activate-ssh` (id_skylake_rescue) is registered in `secrets/secrets.nix`; rotate by re-encrypting the `.age` and updating root's authorized key in `machines/skylake/default.nix`.

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
