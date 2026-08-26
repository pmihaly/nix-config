#!/usr/bin/env sh
# Deploy skylake, auto-answering deploy-rs's interactive sudo prompt.
#
# deploy-rs (interactiveSudo = true; see deploy.nodes.skylake in flake.nix)
# rewrites the remote command to `sudo -S -p ""` and asks for the sudo
# password locally via rpassword, which reads from /dev/tty — so the
# password cannot be fed through stdin or a pipe.
#
# This wrapper runs deploy under util-linux `script`, which gives it a
# pseudo-terminal, and feeds the password from the gitignored file
# machines/skylake/sudo-password. The line is queued in the pty's line
# discipline and consumed when rpassword opens /dev/tty a few minutes
# later. `script -e` propagates deploy's exit code.
#
# Caveat: the password is echoed once at the top of the output (the pty is
# in echo mode until rpassword turns it off). That is local-terminal-only
# exposure, the same as typing it by hand.
#
# Usage:
#   scripts/deploy-skylake.sh              # deploy .#skylake
#   scripts/deploy-skylake.sh CMD [ARGS]   # run CMD under the pty (testing)

set -eu

cd "$(dirname "$0")/.."
PW_FILE="machines/skylake/sudo-password"

if [ ! -s "$PW_FILE" ]; then
    echo "error: $PW_FILE is missing or empty" >&2
    exit 2
fi

cmd="${*:-deploy -s .#skylake}"
{ cat "$PW_FILE"; echo; } | script -q -e -c "$cmd" /dev/null
