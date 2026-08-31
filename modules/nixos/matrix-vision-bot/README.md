# Matrix vision bot — deployment

Reacts to `m.image` messages on the Matrix homeserver, runs each image through
an OpenAI-compatible vision model (OpenRouter by default), and replies in the
same room with the model's description.

This module is the Nix deployment of the `matrix-vision-bot-env` flake
(reference workspace `t_84e3691e`): the bot source is vendored under
`src/` and built from **this repo's locked nixpkgs** (`flake.lock`), so the
runtime is reproducible across dev and skylake — same nixpkgs commit, same
Python, same `matrix-nio`/`openai`/`pillow` versions.

## What it does

- `pkgs.python312.withPackages` builds the runtime: `matrix-nio`, `aiohttp`,
  `pillow`, `requests`, `numpy`, `openai`.
- `ffmpeg` is on the service PATH (codecs for HEIC/HEIF etc.) via the same
  `makeWrapper` shape as the reference flake.
- A `systemd` unit `matrix-vision-bot.service` runs `python -m matrix_bot`
  with `PYTHONPATH=$out/src` under an unprivileged `matrix-vision-bot` user.
- agenix materializes the existing committed secrets
  (`secrets/matrix-bot.age`, `secrets/openrouter-api-key.age`) to
  `/run/agenix/matrix-vision-bot/*` and the unit reads them via
  `EnvironmentFile`. **No secret value is ever committed or placed in the Nix
  store** — only the `.age` ciphertexts in `secrets/`.

## Env contract

Provided by `matrix-bot.age` (env-file format): `MATRIX_HOMESERVER`,
`MATRIX_BOT_USER` (the bot's own id), `MATRIX_ACCESS_TOKEN`,
`MATRIX_HOME_ROOM`.

Provided by `openrouter-api-key.age`: `OPENROUTER_API_KEY` (vision provider).

The unit maps `MATRIX_BOT_USER → MATRIX_USER_ID` at `ExecStart` (same value;
the two names differ because the hermes module consumed the secret first).

Optional tuning (module options, defaults shown):

| Option | Default | Env var |
|---|---|---|
| `allowedUsers` | `[]` (any user) | `MATRIX_ALLOWED_USERS` |
| `maxImageRate` | `6` | `MATRIX_MAX_IMAGE_RATE` |
| `maxConcurrent` | `2` | `MATRIX_MAX_CONCURRENT` |
| `analysisPrompt` | `null` | `MATRIX_ANALYSIS_PROMPT` |

`MATRIX_DEVICE_ID` is pinned to `matrix-vision-bot` so the bot keeps a stable
device identity across restarts.

## Enable

```nix
# machines/skylake/default.nix
modules.matrix-vision-bot = {
  enable = true;
  allowedUsers = [ "@misi:matrix.skylake.mihaly.codes" ];
};
```

The module (and the reference bot) only reads **plaintext** rooms — matrix-nio
as pinned has no libolm (same gap as the hermes Matrix adapter). The bot posts
a notice if it lands in an encrypted room.

## Deploy (single command)

On skylake (as misi):

```sh
cd ~/.nix-config
make skylake        # or: nixos-rebuild switch --flake .#skylake
```

After activation:

```sh
systemctl status matrix-vision-bot     # running?
journalctl -u matrix-vision-bot -f     # live logs
systemctl restart matrix-vision-bot    # apply config/tuning changes
```

The unit starts on boot (`multi-user.target`) and restarts on failure.

## Prerequisites / adding a bot to a NEW homeserver

1. Create the bot account on the homeserver; set a device display name.
2. Encrypt an env-file with the bot credentials for `misi` + the target
   machine's host key, and place it at `secrets/matrix-bot.age`:
   ```
   MATRIX_HOMESERVER=https://matrix.example.org
   MATRIX_BOT_USER=@bot:example.org
   MATRIX_ACCESS_TOKEN=syt_...
   MATRIX_BOT_PASSWORD=   # only if password login is used
   MATRIX_HOME_ROOM=!room:example.org
   ```
   (add the file to `secrets/secrets.nix` with `publicKeys = allKeys`).
3. Create/point `secrets/openrouter-api-key.age` at an OpenAI-compatible
   vision endpoint key (`OPENROUTER_API_KEY=...`).
4. Enable the module as above and run the single deploy command.

## Invite + test

Invite the bot into an unencrypted room, send an image, and it replies with
the vision model's description. Check the vision provider's usage page for the
API call.
