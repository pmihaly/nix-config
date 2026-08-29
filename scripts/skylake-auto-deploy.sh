#!/run/current-system/sw/bin/sh
# Auto-deploy skylake from GitHub (gitops) — run by the skylake-auto-deploy
# systemd timer on aesop as hermes-deploy.
#
# hermes on skylake NEVER ssh's to deploy: she commits in the skylake
# checkout and PUSHES to github.com (that push is her only ssh channel —
# the hermes-github-ssh key). This timer notices the branch advancing,
# pulls it into a dedicated deploy checkout (public https, anonymous — no
# keys anywhere on this path), and runs scripts/deploy-skylake.sh: build
# on aesop, activate skylake as root over ssh (deploy-rs; the activation
# hop is authenticated with the agenix secret server/skylake-activate-ssh,
# materialized by aesop itself — nothing is copied between machines).
set -eu

PATH=/run/current-system/sw/bin:/run/wrappers/bin:/usr/local/bin:/usr/bin:/bin
export PATH

DEPLOY_REPO=/var/lib/hermes-deploy/nix-config
GITHUB_URL=https://github.com/pmihaly/nix-config
BRANCH=vibecode
# Lock file must live where hermes-deploy can write (/run/lock is
# root-owned); it only guards concurrent timer ticks — a manual
# `make skylake` racing the timer is still operator's business.
LOCK=/var/lib/hermes-deploy/.auto-deploy.lock

if [ ! -d "$DEPLOY_REPO/.git" ]; then
  echo "error: $DEPLOY_REPO is not a git repository (created by the hermes-deploy-repo activation script)" >&2
  exit 2
fi

# Never run two deploys at once (timer tick vs a manual `make skylake`).
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another deploy is in progress; skipping this tick"
  exit 0
fi

# Public repo, anonymous https. FETCH_HEAD afterwards = branch tip.
git -C "$DEPLOY_REPO" fetch --force "$GITHUB_URL" "$BRANCH"

# refs/heads/deploy tracks the last state we deployed. Nothing new -> no-op.
if git -C "$DEPLOY_REPO" rev-parse -q --verify refs/heads/deploy >/dev/null 2>&1; then
  if [ "$(git -C "$DEPLOY_REPO" rev-list --count refs/heads/deploy..FETCH_HEAD)" = "0" ]; then
    echo "== $BRANCH unchanged since last deploy; nothing to do"
    exit 0
  fi
  if ! git -C "$DEPLOY_REPO" merge --ff-only FETCH_HEAD; then
    echo "error: $BRANCH diverged from the last deployed state; refusing to deploy" >&2
    echo "hint: if a branch rewrite was intended, force-push and re-align" >&2
    exit 3
  fi
else
  # First run: seed the deploy branch from GitHub's current tip WITHOUT
  # deploying. This protects a machine that is already ahead of the repo
  # (e.g. after a local bootstrap) from being rolled back to the last
  # pushed rev — the first real deploy only happens once the branch
  # advances past this baseline.
  git -C "$DEPLOY_REPO" checkout -q -b deploy FETCH_HEAD
  echo "== seeded deploy baseline at $(git -C "$DEPLOY_REPO" rev-parse --short deploy); will deploy when $BRANCH advances past it"
  exit 0
fi

echo "== deploying $(git -C "$DEPLOY_REPO" rev-parse --short HEAD) ($BRANCH)"
exec "$DEPLOY_REPO/scripts/deploy-skylake.sh"
