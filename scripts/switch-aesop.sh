#!/usr/bin/env sh
# Switch aesop (local `nixos-rebuild switch --flake .#aesop`),
# auto-answering the sudo prompt.
#
# The sudo password comes from the gitignored file
# machines/aesop/sudo-password (chmod 600 — same local-secrets policy as
# machines/skylake/sudo-password). It is fed to `sudo -S` over a plain
# pipe. No pty is needed here: the pty trick in deploy-skylake.sh exists
# because deploy-rs's rpassword reads /dev/tty minutes into the deploy,
# whereas this sudo prompts immediately and `sudo -S` reads stdin.
#
# Usage:
#   scripts/switch-aesop.sh              # sudo nixos-rebuild switch
#   scripts/switch-aesop.sh CMD [ARGS]   # run CMD under sudo (testing)

set -eu

cd "$(dirname "$0")/.."
PW_FILE="machines/aesop/sudo-password"

if [ ! -s "$PW_FILE" ]; then
    echo "error: $PW_FILE is missing or empty" >&2
    echo "create it with:  read -rsp 'aesop sudo password: ' pw && printf '%s\\n' \"\$pw\" > machines/aesop/sudo-password && chmod 600 machines/aesop/sudo-password" >&2
    exit 2
fi

# --flake form: the plain `nixos-rebuild switch` needs a nixos channel in
# NIX_PATH, which this machine doesn't have.
if [ "$#" -gt 0 ]; then
    { cat "$PW_FILE"; echo; } | sudo -S -p '' "$@"
else
    { cat "$PW_FILE"; echo; } | sudo -S -p '' nixos-rebuild switch --flake .#aesop
fi
