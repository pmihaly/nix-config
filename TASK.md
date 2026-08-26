# TASK: Hermes Agent on skylake

Install [Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous
Research) on skylake, declaratively via Nix, state under `/persist`, Web UI
exposed **internally** (tailnet only, no login), LLM backend =
**llama-swap on aesop**.

## Status: DEPLOYED & VERIFIED (2026-08-26) — only WhatsApp pairing left

Everything is live on skylake: login-free dashboard behind the tailnet-only
`/hermes` proxy (blank-page fix in), llama-swap backend, and **WhatsApp
armed** (bridge deployed, npm deps installed, adapter loaded — see below).

The only remaining user action is the **one-time WhatsApp pairing** (scan a
QR from the dashboard). Until then the gateway service intentionally
restart-loops with a "pair me" status (upstream design; harmless — see
WhatsApp section).

The first deployed revision had a **blank white page**: the `/hermes` nginx
location double-slashed upstream URIs (`//assets/…`), so the SPA catch-all
served `index.html` for every asset. Root-caused against nginx 1.30.4
source + strace and fixed (see below); the fix is verified end-to-end
locally with the exact generated config and the real app.

### What changed vs. the first (deployed) revision

| Before                                                    | Now                                                           |
| --------------------------------------------------------- | ------------------------------------------------------------- |
| Dashboard bound `0.0.0.0:9119`, port open on `tailscale0` | Dashboard bound **`127.0.0.1:9119`**, port not exposed at all |
| Web login (basic-auth from agenix secret)                 | **No login** — loopback bind keeps the auth gate off entirely |
| `mkService` redirect `…ts.net/hermes → :9119`             | nginx **`location /hermes` proxy** on the ts.net vhost        |
| `server/hermes-agent-env.age` secret                      | **Deleted** (no secrets left)                                 |

Why loopback instead of `--insecure` 0.0.0.0: since 0.20.5, `--insecure` is a
no-op — a non-loopback bind _always_ engages the dashboard auth gate
(`should_require_dashboard_auth()` in `web_server.py`), and the only gate-free
mode is a loopback bind. Access control is then the tailnet: the `/hermes`
location is restricted with `allow 100.64.0.0/10; deny all;` even though the
ts.net vhost is served on public 80.

### The blank-page bug (found after first deploy, fixed)

Symptom: dashboard HTML loaded, but every asset request came back as
`index.html` → blank white page. strace on skylake showed nginx forwarding
`GET //assets/…` (double slash) upstream.

Root cause (nginx 1.30.4, `src/http/modules/ngx_http_proxy_module.c`):
when `proxy_pass` has a URI part, nginx strips exactly the **location name**
(`loc_len = min(location.len, uri.len)`) and prepends the `proxy_pass` URI.
`location /hermes` (7 chars) + `proxy_pass …9119/` ⇒ `"/" + uri[7:]` =
`"/" + "/assets/…"` = `//assets/…`. The app's `/assets` static mount doesn't
match, the SPA catch-all returns `index.html` for everything. (Trap: local
repro attempts looked "fine" because Python's `http.server` collapses
`//`→`/` in `self.path` and curl squashes `//` without `--path-as-is`.)

Fix: the location name must include the slash, so the math yields a single
slash — `location /hermes/` + `proxy_pass …9119/` ⇒ `"/" + uri[8:]` =
`"/assets/…"`. Plus `location = /hermes { return 301 /hermes/; }` (without
it, bare `/hermes` would fall into the vhost's `location /` → `/homer`).

### How the proxy works (all verified, see smoke tests)

Two locations on `skylake.anaconda-snapper.ts.net` (HTTP vhost):

- `location = /hermes` → 301 `/hermes/` (tailnet-only, same ACL).
- `location /hermes/` with `proxy_pass http://127.0.0.1:9119/;` — the
  trailing-slash location name + proxy URI strip `/hermes/` exactly
  (`/hermes/api/x` → `/api/x`; see the bug note above for why the slash in
  the name is load-bearing).
- `proxy_set_header Host 127.0.0.1;` — the dashboard's Host-header
  (DNS-rebinding) guard only accepts loopback names for loopback binds;
  external Hosts get 400. `recommendedProxySettings = false` because the
  included `proxy_set_header Host $host` would override the rewrite.
- `proxy_set_header Origin "";` — empty value makes nginx omit the header;
  the WS Origin guard accepts a missing Origin (an external one gets 403).
- `proxy_set_header X-Forwarded-Prefix /hermes;` — the prefix-aware SPA
  rewrites its own asset URLs to `/hermes/…` (see `mount_spa()`); JS/CSS are
  served with rewritten internal `url()` refs.
- `proxyWebsockets = true` + 1 h read/send timeouts (agent runs are long).
- uvicorn keeps `proxy_headers` off (only on in gated mode), so the WS
  loopback-**peer** check sees the nginx process on 127.0.0.1, not
  X-Forwarded-For.

### Smoke tests (local, hermes 0.20.5 minimal build, loopback bind, no creds)

- Dashboard starts, no auth provider configured → no login page.
- `Host: 127.0.0.1` → 200; `Host: skylake.anaconda-snapper.ts.net` → 400.
- `X-Forwarded-Prefix: /hermes` → HTML contains
  `__HERMES_BASE_PATH__="/hermes"`, all asset refs `/hermes/assets/…`,
  prefixed JS asset fetch → 200.
- WS upgrade, no Origin, valid session token → `101 Switching Protocols`;
  with external Origin → `403` (proves the Origin strip is load-bearing).
- `/api/status` → JSON (version 0.20.5).
- **Full nginx→app pass** (generated config from the flake build, real
  app, nginx 1.30.4, accessed via tailnet IP so the ACL engages):
  - `/hermes` → `301 /hermes/`; `/hermes/` → 200 HTML with
    `__HERMES_BASE_PATH__="/hermes"` and `/hermes/assets/…` refs.
  - `/hermes/assets/index-*.js` → **200 `text/javascript`** (64 KB real
    bundle — this is the request the old config mangled into
    `//assets/…`→index.html); nonexistent asset → **404**, not index.html.
  - `/hermes/api/status` → 200 `application/json`.
  - ACL: loopback source → 403, tailnet source → 200.
  - WS handshake passthrough: response identical to hitting the app
    directly (tokenless handshakes get the app's own 403 on both paths).

## Access after deploy

- **Dashboard:** `http://skylake.anaconda-snapper.ts.net/hermes/`
  (tailnet only — anything else is denied at nginx; no login).
  Card on the private Homer board (AI › Hermes) points there.
- Port 9119 is no longer reachable directly, even on the tailnet.
- Old bookmarks to `:9119` / `mihaly.codes/hermes` stop working by design —
  the vhost redirect location is gone.

## LLM backend: llama-swap on aesop (unchanged)

`modules/nixos/hermes-agent/default.nix` → `services.hermes-agent.settings`
(deep-merged into `$HERMES_HOME/.hermes/config.yaml` at activation):

```yaml
providers:
  local:
    api: http://aesop.anaconda-snapper.ts.net:8081/v1 # llama-swap, tailnet
    api_key: local
model:
  default: "Qwen3.8-27B Q4 +MTP"
  provider: "custom:local"
```

Nothing secret here (tailnet name is in this repo; llama-swap doesn't enforce
auth), so it lives in Nix `settings`, not in an agenix secret.

Gotchas (verified against hermes 0.20.5 source + live tests on skylake):

- A bare `model: "custom:local:…"` string is NOT enough for runtime provider
  resolution ("No inference provider configured"). The dict form above
  (`model.default` + `model.provider: custom:local`) is what works.
- **Re-assertion on activation:** the merge script gives Nix keys priority, so
  a `make skylake` re-asserts `model`/`providers.local` over dashboard edits.
  Change the default model here, not in the runtime config.
- If the llama-swap model is swapped on aesop, update
  `settings.model.default` (ts.net name survives IP changes).

## What's in the repo

- `flake.nix` — `hermes-agent` flake input (pinned; nixpkgs follows it);
  `nixosModules.hermes-agent.default` on skylake; deploy node (tailscale IP,
  `id_skylake_rescue`, user `misi`→root, `interactiveSudo`).
- `modules/nixos/hermes-agent/default.nix` — enables
  `services.hermes-agent` with:
  - `package = inputs.hermes-agent.packages.${pkgs.stdenv.system}.minimal`
    (skips the optional integration groups; the `full` default pulls matrix,
    voice, modal, daytona, … and builds much longer).
  - `stateDir = /persist/opt/skylake-services/hermes` (skylake root is tmpfs;
    this path is in the restic backup list).
  - `backend = { mode = "dashboard"; host = "127.0.0.1"; port = 9119; }` —
    loopback ⇒ no auth gate ⇒ no login (see table above).
  - `settings` — the llama-swap provider/model wiring above.
  - nginx `location /hermes/` proxy (+ `location = /hermes` 301) with
    `allow 100.64.0.0/10; deny all;` (the only exposure) + Homer card
    (AI › Hermes, `hermes.png`).
- `use-cases/server/default.nix` — `hermes-agent.enable = true` (skylake).
- Registered in `modules/nixos/default.nix`.
- **No secrets** for hermes anymore (`server/hermes-agent-env.age` deleted).

## Services (after deploy)

- `hermes-agent.service` — agent gateway (`hermes gateway`), user `hermes`.
- `hermes-backend.service` — dashboard:
  `hermes dashboard --host 127.0.0.1 --port 9119 --no-open`, user `hermes`.

## WhatsApp support (added 2026-08-26, deployed & verified)

Symptom (from the dashboard pairing endpoint after the first deploy):
`500: WhatsApp bridge script was not found at
/nix/store/…-hermes-agent-0.20.5/lib/python3.12/site-packages/scripts/whatsapp-bridge/bridge.js`.

Root cause: the bridge is a small Node app in the repo at
`scripts/whatsapp-bridge/`, but it is **not part of the installed package**
— setuptools only packages Python modules, and the uv2nix venv inherits
that. The runtime copes with read-only installs by design:
`resolve_whatsapp_bridge_dir()` (`gateway/platforms/whatsapp_common.py`)
falls back to a **mirror at `$HERMES_HOME/scripts/whatsapp-bridge`** when
the install-tree copy is missing/writable-check fails. We just pre-populate
that mirror — no patching.

Changes in `modules/nixos/hermes-agent/default.nix`:

- `whatsappBridge` — `pkgs.runCommand` that copies
  `inputs.hermes-agent.sourceInfo/scripts/whatsapp-bridge/` into a store
  path. A derivation (not a bare source sub-path) is **required**:
  store paths embedded in activation-script strings are NOT part of the
  toplevel closure, so a plain `cp ${…sourceInfo}/…` would fail on skylake
  (verified: the source path is absent there). The drv + its source input
  are in the built toplevel closure (checked with `nix path-info --recursive`).
- `system.activationScripts."hermes-whatsapp-bridge"` — copies the bridge
  into `/persist/opt/skylake-services/hermes/.hermes/scripts/whatsapp-bridge`,
  `chown hermes:hermes` + `chmod u+rwX` (npm needs to write `node_modules/`).
  `deps = [ "users" "hermes-agent-setup" ]` so the user and `$HERMES_HOME`
  exist first. Re-copied on every switch → input bumps refresh the bridge;
  `node_modules/` survives (it's created at runtime, not in the store).
- `services.hermes-agent.environment.WHATSAPP_ENABLED = "true"` — arms the
  bundled `whatsapp-platform` adapter (its `requires_env` gate reads
  `$HERMES_HOME/.env`, which the upstream activation script writes from
  `environment`). Verified in the built system: `hermes-env-base` =
  `WHATSAPP_ENABLED=true`.
- `services.hermes-agent.extraPackages = [ whatsappBridge ]` — the closure
  hook (flows to `users.users.hermes.packages`; the derivation has no
  `bin/`, so nothing lands on the PATH).

Runtime behavior (verified against 0.20.5 source + docs):

- **Self-chat mode is the default** (`WHATSAPP_MODE` unset) — the agent
  links **your own** WhatsApp account; no second/bot number needed.
- DM and group policy default to **`pairing`**: nobody can reach the agent
  until you pair through the dashboard — arming the adapter ahead of time
  is safe.
- First pairing runs `npm install` in the bridge dir (needs writable dir ✓
  and network ✓ — the service is not network-sandboxed; timeout 300 s).
- node/npm resolution: `ExecStart` is the **wrapped** hermes binary, whose
  env already puts `node`/`npm` on PATH and sets `HERMES_NODE` — both the
  gateway and dashboard services spawn from it.
- The Baileys session lives under the bridge dir in HERMES_HOME → on
  `/persist`, survives reboots; re-scan only when the session is reset.
- The bridge computes a script hash on start; the gateway restarts a
  running bridge when the on-disk code changes (input bump → refresh).

Live verification on skylake (2026-08-26, post-deploy):

- Bridge tree in `$HERMES_HOME/scripts/whatsapp-bridge`, `hermes:hermes`,
  user-writable; `.env` = `WHATSAPP_ENABLED=true`.
- WhatsApp plugin **loaded** — gateway log shows
  `hermes_plugins.whatsapp_platform.adapter: [Whatsapp] WhatsApp is enabled
but not paired` (the exact intended pre-pairing state; the 500 is gone).
- node/npm resolution confirmed from the real service env
  (`HERMES_NODE=…nodejs-26-npm-12/bin/node` + node bin on PATH);
  `npm install` pre-run in the bridge dir (118 packages) so pairing is
  instant.
- `bridge.js` smoke run (15 s, as `hermes`): starts clean —
  "WhatsApp bridge listening on port 3000 (mode: self-chat)", prints the
  pairing QR, stays idle (healthy unpaired state).
- Adapter passes `--session $HERMES_HOME/platforms/whatsapp/session` when
  it spawns the bridge, so `creds.json` lands exactly where the adapter's
  pre-flight checks for it.

**Expected until pairing:** `hermes-agent.service` (the gateway) restarts
~every 8 s, each cycle logging "WhatsApp enabled but not paired" and
writing `gateway_state=startup_failed`. That is the upstream design
(`Restart=always` default; exit-78 "fatal config" when **no** platform
connects — WhatsApp is the only one, unpaired). It costs nothing: the
gateway has no other duty (no cron, no other platforms), and browser chat
runs in the separate `hermes-backend` service, which is up. The moment
`creds.json` exists, the next cycle connects and the loop ends — no manual
restart needed.

## Remaining user steps

1. **WhatsApp pairing** (one-time): open
   `http://skylake.anaconda-snapper.ts.net/hermes/` → WhatsApp tab →
   start pairing → scan the QR with the phone that should be the
   agent's account. (npm deps are pre-installed, so this is instant.)
2. After scanning: the gateway's restart loop ends on its own — verify
   `systemctl is-active hermes-agent` stays `active` for a minute and
   `journalctl -u hermes-agent -n 20` shows the bridge connecting
   (`status:connected`). Then DM your own WhatsApp number to talk to the
   agent (self-chat mode).
3. LLM end-to-end sanity (optional): on skylake
   `sudo runuser -u hermes -- /nix/store/…-hermes-agent-0.20.5/bin/hermes -z "ping"`
   (answers via aesop llama-swap), or just chat in the browser dashboard.

## Already verified live (2026-08-26, post-deploy)

- `systemctl is-active hermes-agent hermes-backend` → active/active
  (gateway "active" = mid restart-loop, see WhatsApp section).
- `HERMES_DASHBOARD_READY port=9119` in `hermes-backend` log.
- Via the ts.net name from aesop: `/hermes/` → 200 with
  `__HERMES_BASE_PATH__="/hermes"`; JS asset → `200 text/javascript`.

## Git state

All committed: ntfy + deploy wiring (`2c52c2c`), Hermes install incl.
blank-page fix (`fa6b64a`), WhatsApp bridge + adapter (`45667f8`), plus
this `TASK.md` update. Only unrelated `modules/nixos/copyparty/UPGRADING.md`
drift remains uncommitted.
