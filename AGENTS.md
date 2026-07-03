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
- Deploy skylake server: `make skylake` (runs `deploy -s .#skylake`)
- Build aesop (test Nix changes): `nix build .#nixosConfigurations.aesop.config.system.build.toplevel`

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
