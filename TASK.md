# TASK: Hermes Agent on skylake

Install [Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous
Research) on skylake, declaratively via Nix, state under `/persist`, Web UI
exposed **internally** (tailnet only, no login), LLM backend =
**llama-swap on aesop**, notes search via **FlowState-QMD (MCP)**.

## Status: QMD NOTES SEARCH — DEPLOYED & VERIFIED (2026-08-26)

**FlowState-QMD** is live as the `qmd` MCP server: the collection
`hermes-memories` tracks `$HERMES_HOME/.hermes/memories/`, the daily
`hermes-qmd-embed` timer keeps the index/embeddings fresh, and the gateway
spawns `qmd mcp` (verified: tools listed, lex + vec queries run as user
`hermes`). Reranking is patched off (native crash, see below). See the QMD
section for the full state.

## Status: DEPLOYED & VERIFIED (2026-08-26) — WhatsApp PAIRED & ENABLED

Everything is live on skylake: login-free dashboard behind the tailnet-only
`/hermes` proxy (blank-page fix in), llama-swap backend. **WhatsApp is
paired and armed**: the QR pairing succeeded (creds saved to the canonical
session path), the `whatsapp` flag is on, and the gateway's bridge
reconnected with the saved session — **no second QR needed** (bridge.log:
"✅ WhatsApp connected!"). One step left for the user: the one-time **DM
pairing approval** (see Remaining user steps).

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

## WhatsApp support (added 2026-08-26) — PAIRED & ENABLED (2026-08-26)

### Final state (after reset + re-pair, verified live)

- `hermes-agent.whatsapp = true` in `use-cases/server/default.nix`;
  `$HERMES_HOME/.env` = `WHATSAPP_ENABLED=true`.
- Pairing via **dashboard QR** after the reset linked cleanly (phone shows
  "hermes" under linked devices). Full Baileys session (creds + 1300+ auth
  files) in `$HERMES_HOME/platforms/whatsapp/session/`, owner `hermes`.
- Post-deploy gateway (PID 85530) loaded the adapter, spawned the bridge as
  a child (`node bridge.js --port 3000 --session …/whatsapp/session
  --mode self-chat`); `bridge.log` → "✅ WhatsApp connected!" 18:20:06.
  Stable — no restart loop. Proctitle quirk: the bridge process shows as
  `node-MainThread`, so `pgrep -x node` does not match it.
- The "enabled but not paired" message seen after scanning was **stale**
  (last emitted 17:56, pre-reset). The post-reset gateway had the platform
  off entirely — pairing had succeeded, but the flag was still off.
- DM layer: policy `pairing` (default), empty allowlist → first
  self-chat message triggers the DM pairing handshake (bot replies with a
  pairing code; approve once). Approved users persist in the PairingStore
  JSON under `$HERMES_HOME` — survives deploys (only `.env` is rewritten
  by the upstream state script).
- The dashboard onboarding session is in-memory in `hermes-backend`;
  the deploy restart dropped it, so the UI's "Apply" step is gone. The
  gateway-side pairing handshake is the remaining path (no new QR).

### Why the bridge mirror exists

Symptom (from the dashboard pairing endpoint after the first deploy):
`500: WhatsApp bridge script was not found at
/nix/store/…-hermes-agent-0.20.5/lib/python3.12/site-packages/scripts/whatsapp-bridge/bridge.js`.

Root cause: the bridge is a small Node app in the repo at
`scripts/whatsapp-bridge/`, but it is **not part of the installed package**
(setuptools only packages Python modules; the uv2nix venv inherits that).
The runtime copes by design: `resolve_whatsapp_bridge_dir()`
(`gateway/platforms/whatsapp_common.py`) falls back to a **mirror at
`$HERMES_HOME/scripts/whatsapp-bridge`** when the install-tree copy is
missing. `whatsappBridge` (runCommand over
`inputs.hermes-agent.sourceInfo/scripts/whatsapp-bridge`) + the
`hermes-whatsapp-bridge` activation script pre-populate that mirror.
A derivation — not a bare source sub-path — is **required**: store paths
embedded in activation-script strings are NOT part of the toplevel
closure, so a plain `cp ${…sourceInfo}/…` would fail on skylake (verified).

### The config is now gated

`modules.hermes-agent.whatsapp` (bool, default **false**; skylake sets
nothing, so it is off). When **true**:

- `environment.WHATSAPP_ENABLED = "true"` (lands in `$HERMES_HOME/.env`,
  which arms the bundled `whatsapp-platform` adapter via its
  `requires_env` gate),
- `extraPackages = [ whatsappBridge ]` + the activation script that copies
  the mirror into HERMES_HOME (`chown hermes:hermes`, re-copied on every
  switch; `node_modules/` survives — created at runtime, not in the store).

When **false**: none of that is built or run; the mirror already on disk
is left alone (harmless — the plugin does not load without the env var).

Runtime facts (verified against 0.20.5 source + docs): default
**self-chat** mode links **your own** WhatsApp account (no second number);
DM/group policy default to `pairing`; node/npm come from the wrapped hermes
binary's env (`HERMES_NODE=…nodejs-26-npm-12`); while enabled but
unpaired the gateway exit-78 restart-loops (harmless — browser chat is the
separate backend service) until `creds.json` exists.

### What went wrong with the first pairing (why the reset)

- The bundled bridge only pairs via **QR** (`--pair-only`/`--pair-json`);
  it has no pairing-code endpoint. A throwaway helper
  (`pair-code.mjs`, Baileys `sock.requestPairingCode()`) issued codes,
  but each pending registration expires server-side after ~3 min (401)
  unless the phone enters the code in time — two codes
  (`9XD5KXLL`, `YHBK2XC2`) expired unentered.
- A later attempt did write `creds.json` (Web UI showed WhatsApp
  **"connected"**), but the linked device never appeared on the phone and
  the bridge then logged out by itself (`bridge.log`: "❌ Logged out.
  Delete session and restart to re-authenticate.") — a half-linked state
  with no way to make progress from the UI.

### Reset performed (2026-08-26, deployed)

- Added the `whatsapp` flag (off); deployed via `make skylake`.
- **Stale `.env` gotcha:** the upstream state script writes `.env` **only
  when** `environment`/`environmentFiles` are non-empty
  (`moduleCommon.nix`, mkStateScript) — so flipping the flag off left
  `WHATSAPP_ENABLED=true` in the on-disk `.env`, and the restarted gateway
  came up with WhatsApp still armed ("enabled but not paired", session
  already wiped). The line was removed manually (inode-preserving rewrite,
  owner `hermes:hermes` kept) and `hermes-agent` restarted.
- Wiped `$HERMES_HOME/platforms/whatsapp` (session `creds.json`,
  `bridge.log`), the pair-code helper and its log.
- Verified after: `.env` empty (0 bytes), no node processes, gateway log:
  **"No messaging platforms enabled."**, both services active, dashboard
  `/api/health` → 200.

### Left in place (so re-enabling is instant)

- Bridge mirror + pre-installed `node_modules` (118 packages) in
  `$HERMES_HOME/scripts/whatsapp-bridge` — the mirror re-copy only runs
  while `whatsapp = true`, but the npm deps survive either way, so no
  2-minute `npm install` before pairing.

### To reset / (re-)enable

- **Reset** (if a pairing goes sideways): flip `hermes-agent.whatsapp`
  to `false`, `make skylake`, remove the stale `WHATSAPP_ENABLED` line
  from `$HERMES_HOME/.env` (the gotcha above),
  `rm -rf $HERMES_HOME/platforms/whatsapp`, restart `hermes-agent`.
- **(Re-)enable**: flag `true` + `make skylake`; pair via dashboard QR
  (pairing-code-flow codes expire ~3 min server-side). While enabled but
  unpaired the gateway exit-78 restart-loops (harmless) until
  `creds.json` exists; then it connects on its own.
- **One-time DM pairing** (the remaining step): send yourself a message
  on WhatsApp → the bot replies with a pairing code → approve:
  `sudo runuser -u hermes -- <hermes-bin> pairing approve whatsapp <code>`
  (or dashboard → pairing). Approved users persist across deploys.

## Notes search: FlowState-QMD (MCP) — added 2026-08-26

### Design

Hermes' built-in memory = `MEMORY.md` + `USER.md` in
`$HERMES_HOME/memories/`, loaded **in full** into the system prompt. As
notes accumulate, QMD adds *search* over that corpus:

- **Collection** `hermes-memories` → `$HERMES_HOME/memories` (the dir the
  memory tool writes to; the agent can drop extra `*.md` notes there).
- **MCP server** (stdio, spawned by the gateway): `qmd mcp` — tools
  `query` (embeddings + rerank), `get`/`multi_get`, `status`,
  `fetch_anticipatory_context` (falls back to a live query when the
  anticipatory cache is cold — fine for notes).
- **Lite model profile** (skylake = 2 vCPU / 4 GB — the repo defaults,
  4B embed + 4B rerank + 1.7B query-expansion, don't fit):
  - `QMD_EMBED_MODEL` = Qwen3-Embedding-0.6B Q8_0 (~0.7 GB).
  - **Rerank is disabled by source patch** (crash, see below); the 0.6B
    Q4_K_M rerank model is still pre-staged, so re-enabling = env var +
    un-patch, no download.
  - the 1.7B expansion model is **not** env-overridable, but it only
    loads when the BM25 probe finds no lexical signal (rare for notes).
  - models are **pre-staged at activation** (downloaded once from
    HuggingFace into `$HERMES_HOME/.cache/qmd/models`, HOME on /persist)
    so first use is offline and no service blocks on a multi-GB fetch.
- **Build**: not on npm under this name (`@tobilu/qmd` is the upstream
  base) → `buildNpmPackage` over the pinned source (flake input
  `flowstate-qmd`, rev in the URL). npm (not bun) on purpose:
  `bin/qmd` picks the runtime by lockfile (npm → `node`), and the native
  modules (better-sqlite3, sqlite-vec, node-llama-cpp) install for the
  build-time nodejs — the runtime `node` (nodejs-slim, same major as the
  WhatsApp bridge) matches that ABI.
- **Ops wiring** (all in `modules/nixos/hermes-agent/default.nix`,
  gated by `modules.hermes-agent.qmdMemory`, set true for skylake in
  `use-cases/server/default.nix`):
  - `mcpServers.qmd` = `{ command = …/bin/qmd; args = [ "mcp" ]; env = … }`
    (merged into `settings.mcp_servers` by the upstream module).
  - The derivation also **rebuilds the launcher**: the npm bin script
    resolves its package dir through the `$out` symlink chain, which
    breaks in the nix store (the real package lives one level up under
    `lib/node_modules`) — so `$out/bin/qmd` is a symlink to the package
    bin, which `exec`s a **pinned** nodejs-slim binary (not `exec node`;
    the service PATH has no node).
  - activation script `hermes-qmd-memory`: creates + `chown`s the XDG
    dirs (`.config/qmd`, `.cache/qmd` — a root-owned `.cache` from
    pre-staging breaks `better-sqlite3`'s temp-file journaling with
    `SQLITE_CANTOPEN`), pre-stages the GGUF models, then idempotent
    `qmd collection add …/memories --name hermes-memories` as user
    `hermes` (no model load → fast/offline).
  - `hermes-qmd-embed.service` + daily timer (`Persistent`, +30 min
    random delay): `qmd update && qmd embed` as a short-lived process —
    `update` re-scans the collection (new/changed notes), `embed` fills
    embeddings for changed content hashes only (model RAM released on
    exit). The MCP `query` tool does **not** re-index (its `refresh`
    option is anticipatory-cache only), so without the timer, new notes
    would never be found.
  - Steady-state cost: the MCP child holds the embed model (~0.7 GB)
    once the first query loads it (kept warm 5 min per node-llama-cpp
    lifecycle; no rerank model — patched off).

### Build & runtime fixes (found by testing on skylake)

1. **npm dep hash**: the pinned flake rev's commit was made before its
   `package-lock.json` was updated (lock lacked `@vscode/ripgrep`'s
   platform packages) → `buildNpmPackage`'s integrity check failed.
   Fixed by vendoring the lockfile at `vendor/flowstate-qmd-package-lock.json`
   (content verified against the published tarball's) and copying it over
   in `postPatch`.
2. **bin entry** + **node pinning**: as above (launcher section).
3. **Model RAM**: see the rerank crash below — the repo-default 4B
   reranker (~2.6 GB) cannot load on a 4 GB box.

### The rerank crash (found 2026-08-26, fixed via patch)

Symptom: the first MCP `query` that loads the rerank model aborted the
MCP server process: exit 134 (SIGABRT), ~1.4 s into model load, native
assertion `Assertion failed: (env) != nullptr` in
`node::RemoveEnvironmentCleanupHook`, stack through `better-sqlite3`
`Statement::~Statement()` — i.e. a native teardown race between
better-sqlite3's per-Environment cleanup hooks and node-llama-cpp's model
load, **not** an OOM kill. Facts established on skylake:

- reproducible across rerank **and** embed model loads inside the
  long-lived MCP server process (~25 % of load attempts abort;
  initialize-only sessions never load a model and always exit clean);
- the **CLI** path (short-lived process: load → query → exit) never
  crashed in any test, rerank included;
- the identical store path + node binary + models work over MCP on aesop
  (8 GB) — so it's skylake-specific (2 vCPU / 4 GB, teardown timing);
- disabling the query-expansion model was not enough (the crash is in the
  rerank stage, and expansion isn't env-overridable anyway).

Fix (in the derivation's source patch, `src/store.ts`):
`structuredSearch()` skips the rerank stage entirely (lexical + vector
results merged, no `rerankModel` load), and `QMD_RERANK_MODEL` is not set
anywhere (MCP + timer env). Lex+vec over a notes corpus is the useful
signal anyway; rerank quality is marginal at this scale.

**Known residual**: the same native race can still abort the MCP server
when the **embed** model loads (~25 %). Self-healing in practice: the
hermes gateway's MCP client lazily respawns a dead stdio server on the
next tool call (and any successful call — e.g. a lex-only query —
"proves" the session and resets its rapid-drop budget), so the worst
case is one failed tool call the agent retries. If it becomes a real
problem in use, the robust fix is a thin MCP wrapper that delegates
queries to short-lived `qmd query` CLI subprocesses (the crash-free path).

### Verified live (2026-08-26, all as user `hermes` on skylake)

- Collection: `hermes-memories` → `…/.hermes/memories`, pattern
  `**/*.md` (the real runtime notes dir is `.hermes/memories`, not
  `$HERMES_HOME/memories` — the activation script targets the former).
- `qmd status`: index at `…/.cache/qmd/index.sqlite` (on /persist),
  0 documents after the self-test note cleanup.
- `qmd get`, CLI `query` (loads the 0.6B embed model from the
  pre-staged cache) — clean.
- MCP (`qmd mcp`, patched build): `initialize` + `tools/list` → 5 tools
  (`query`, `get`, `multi_get`, `status`, `fetch_anticipatory_context`);
  `query` lex-only → works, no model load; `query` vec → works, loads
  the 0.6B embed model (empty index ⇒ legitimately empty results).
- Gateway runtime config contains `mcp_servers.qmd` pointing at the
  patched store path; the `qmd mcp` child is up under the gateway.
- `hermes-qmd-embed.service`/`.timer` exist, timer `OnCalendar`
  (inactive until the next elapse — correct).
- Self-test note removed; `qmd update` cleaned the orphaned content
  hash (1 orphaned vector remains in the DB — cosmetic, no docs).

### Status

- [x] Source + config investigated; Nix written; eval green.
- [x] Derivation builds (vendored lockfile, symlinked bin, pinned node).
- [x] Deployed; models pre-staged; collection registered on /persist.
- [x] Rerank crash diagnosed + patched off; lex+vec verified over MCP.
- [x] Timer service in place for daily re-index + re-embed.
- [ ] Real-world check: after the agent writes a few notes, ask it to
      find one via WhatsApp (semantic recall end-to-end).

## Remaining user steps

1. ~~WhatsApp one-time DM pairing~~ — **done** (2026-08-26): self-chat
   message triggered the handshake, the code was approved via
   `hermes pairing approve whatsapp` (user "Mihaly", persisted in the
   PairingStore JSON under `$HERMES_HOME`). Self-chat messages now reach
   the agent.
2. LLM end-to-end sanity (optional): send a self-chat message and check
   the agent answers via aesop llama-swap, or chat in the browser
   dashboard.

## Already verified live (2026-08-26, post re-enable)

- `systemctl is-active hermes-agent hermes-backend` → active/active.
- WhatsApp bridge child of the gateway (PID 85653 ← 85530), session =
  canonical path, `--mode self-chat`; `bridge.log` "✅ WhatsApp
  connected!"; no restart loop.
- Dashboard `/api/health` → 200 (loopback); ts.net vhost `/hermes/` → 200
  for tailnet sources (loopback source → 403, ACL working).
- `$HERMES_HOME/.env` = `WHATSAPP_ENABLED=true`; session tree owner
  `hermes:hermes`.
- DM pairing approved (1 user, whatsapp platform) — no pending requests;
  approval persists across deploys.

## Git state

All committed: ntfy + deploy wiring (`2c52c2c`), Hermes install incl.
blank-page fix (`fa6b64a`), WhatsApp bridge + adapter (`45667f8`),
`TASK.md` update (`136cd23`), WhatsApp reset + `whatsapp` flag
(`c0fd213`), WhatsApp re-enable + DM pairing (`67efb22`), QMD notes
search (this commit: flake input + lock, derivation + vendored lockfile,
ops wiring, `TASK.md`).
Only unrelated `modules/nixos/copyparty/UPGRADING.md` drift remains
uncommitted.
