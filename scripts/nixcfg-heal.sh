#!/usr/bin/env bash
# Heal group ownership/permissions on the nix-config checkout on skylake
# so the hermes agent (group `nixcfg`) keeps write access.
#
# Run as root on skylake after any pull/commit done by root or misi —
# they create files without the group write bit (umask), which the
# setgid dirs and core.sharedRepository=group do not fix retroactively.
# See the comment in machines/skylake/default.nix.
set -euo pipefail

REPO="${1:-/home/misi/.nix-config}"
# git is not on root's default PATH on skylake; fall back to the newest
# store git (dirs only, must ship bin/git — keeps out of *.drv, git-crypt).
GIT="${GIT:-$(command -v git || true)}"
if [ -z "$GIT" ]; then
  for d in $(ls -1dt /nix/store/*-git-[0-9]* 2>/dev/null); do
    if [ -x "$d/bin/git" ]; then
      GIT="$d/bin/git"
      break
    fi
  done
fi

chgrp -R nixcfg "$REPO"
chmod -R g+rwX "$REPO"
find "$REPO" -type d -exec chmod g+s {} +

# Files created by any committer get group-shared perms by default.
# (safe.directory for this repo is set in /etc/gitconfig on skylake.)
if [ -n "${GIT:-}" ] && [ -x "$GIT" ]; then
    "$GIT" -C "$REPO" config core.sharedRepository group
else
    echo "heal: git not found; set core.sharedRepository manually" >&2
fi
