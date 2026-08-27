#!/run/current-system/sw/bin/sh
# Deploy skylake from the skylake-side checkout (the one hermes edits on
# skylake at /home/misi/.nix-config), building on aesop.
#
# This is the forced command for the hermes-deploy user on aesop (see
# machines/aesop/default.nix). hermes reaches it with:
#   ssh hermes-deploy@aesop.anaconda-snapper.ts.net
# which sshd immediately replaces with this script — no shell, no other
# commands, no forwarding (restrict).
#
# Flow:
#   1. Update the dedicated deploy checkout /var/lib/hermes-deploy/nix-config
#      (owned by hermes-deploy) from the skylake checkout over ssh+git,
#      fast-forward only.
#   2. Copy the gitignored skylake sudo password into the deploy checkout.
#   3. Run the same deploy-skylake.sh that `make skylake` uses.
#
# The main checkout /home/misi/.nix-config is only ever read for the script
# and the sudo password; hermes-deploy has no write access to it.
set -eu

# Self-contained PATH: forced commands run under a minimal environment
# (PAM usually gives us the system PATH, but don't depend on it).
PATH=/run/current-system/sw/bin:/run/wrappers/bin:/usr/local/bin:/usr/bin:/bin
export PATH

DEPLOY_REPO=/var/lib/hermes-deploy/nix-config
SKYLAKE_HOST=100.69.8.15
SKYLAKE_REPO=/home/misi/.nix-config
SKYLAKE_SSH_KEY=/home/misi/.ssh/id_skylake_rescue
PASSWORD_SRC=/home/misi/.nix-config/machines/skylake/sudo-password

if [ ! -d "$DEPLOY_REPO/.git" ]; then
  echo "error: $DEPLOY_REPO is not a git repository (created by the hermes-deploy-repo activation script)" >&2
  exit 2
fi

export GIT_SSH_COMMAND="ssh -i $SKYLAKE_SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

echo "== fetching skylake vibecode -> $DEPLOY_REPO (ff-only)"
git -C "$DEPLOY_REPO" fetch origin vibecode

if git -C "$DEPLOY_REPO" rev-parse -q --verify refs/heads/vibecode >/dev/null 2>&1; then
  if ! git -C "$DEPLOY_REPO" merge --ff-only FETCH_HEAD; then
    echo "error: skylake vibecode has diverged from the deploy checkout; refusing to deploy" >&2
    echo "hint: resolve on skylake (git -C $SKYLAKE_REPO pull --ff-only) and re-run" >&2
    exit 3
  fi
else
  git -C "$DEPLOY_REPO" checkout -q -b vibecode FETCH_HEAD
fi
echo "== deploy checkout at: $(git -C "$DEPLOY_REPO" rev-parse --short HEAD)"

cp -f "$PASSWORD_SRC" "$DEPLOY_REPO/machines/skylake/sudo-password"
chmod 600 "$DEPLOY_REPO/machines/skylake/sudo-password"

exec "$DEPLOY_REPO/scripts/deploy-skylake.sh"
