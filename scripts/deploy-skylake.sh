#!/usr/bin/env sh
# Deploy skylake with deploy-rs.
#
# deploy-rs connects as root over the tailnet (deploy.nodes.skylake in
# flake.nix: sshUser=user=root, no interactive sudo) — so no password
# prompt and no pty tricks. Only the ssh key matters: `make skylake`
# (misi on aesop) reads ~/.ssh/id_skylake_rescue; the skylake-auto-deploy
# timer (hermes-deploy) reads the same keypair via the agenix secret
# /run/agenix/server/skylake-activate-ssh.
#
# Used by `make skylake` and by scripts/skylake-auto-deploy.sh (which
# runs it from the deploy checkout as hermes-deploy).
set -eu

cd "$(dirname "$0")/.."

exec deploy -s .#skylake