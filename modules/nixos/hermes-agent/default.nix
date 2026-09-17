{
  inputs,
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.hermes-agent;

  # Hermes' built-in dashboard port (web_server.py default; the NixOS
  # module's backend.port also defaults to it).
  port = 9119;

  # The service user/group and HERMES_HOME — where the runtime keeps
  # .env, config.yaml, the WhatsApp session, and (for read-only
  # installs) the WhatsApp bridge mirror (see whatsappBridge below).
  hermesCfg = config.services.hermes-agent;
  hermesHome = "${hermesCfg.stateDir}/.hermes";

  # WhatsApp bridge: a small Node app that lives in the hermes-agent
  # repo under scripts/whatsapp-bridge/ but is NOT shipped in the
  # installed package — setuptools only packages Python modules, and
  # the uv2nix venv inherits that. resolve_whatsapp_bridge_dir()
  # (gateway/platforms/whatsapp_common.py) copes with read-only
  # installs by falling back to a mirror at
  # $HERMES_HOME/scripts/whatsapp-bridge when the install-tree copy is
  # missing — this is that mirror (without it, the dashboard's WhatsApp
  # pairing endpoint 500s with "bridge script was not found").
  #
  # A derivation (rather than the source sub-path directly) so the
  # store path is a real dependency of the system: `make skylake`
  # copies the toplevel's closure to skylake, and a path that merely
  # appears in an activation-script string would not be in it.
  whatsappBridge = pkgs.runCommand "hermes-whatsapp-bridge" { } ''
    mkdir -p $out
    cp -rT ${inputs.hermes-agent.sourceInfo}/scripts/whatsapp-bridge $out
  '';

  # FlowState-QMD — "anticipatory memory" MCP server (a hackathon
  # project built on tobi/qmd: a sqlite-vec embedding index over
  # markdown). Here it earns its keep in its core job: making the
  # agent's own notes ($HERMES_HOME/memories) searchable. Not on npm
  # under this name (the npm `@tobilu/qmd` is the upstream base, not
  # the fork), so it is built from the pinned source (flake input).
  #
  # Built with npm, NOT bun, on purpose: bin/qmd picks the runtime by
  # lockfile (package-lock.json -> node), and the native modules
  # (better-sqlite3, sqlite-vec, node-llama-cpp) are installed for the
  # nodejs in the build env — the runtime `node` (nodejs-slim, same
  # major as the WhatsApp bridge uses) must match that ABI.
  qmd = pkgs.buildNpmPackage {
    pname = "flowstate-qmd";
    version = "1.0.0";
    src = inputs.flowstate-qmd;
    # better-sqlite3 falls back to a node-gyp compile when no prebuild
    # matches the node ABI; keep the toolchain available for that.
    nativeBuildInputs = [
      pkgs.python3
      pkgs.nodejs
    ];
    postPatch = ''
        # Upstream ships bun.lock only (it is a bun project); buildNpmPackage
        # requires an npm lockfile. Vendor one generated at the pinned rev
        # so dependency versions (incl. the platform-specific node-llama-cpp
        # prebuilds) stay exactly pinned.
        cp ${./vendor/flowstate-qmd-package-lock.json} package-lock.json

        # The MCP `query` tool accepts a `rerank` flag, but loading the rerank
      # model inside the long-lived MCP *server* process aborts natively on
      # skylake (better-sqlite3 teardown assertion
      # `RemoveEnvironmentCleanupHook: (env) != nullptr`, reproduced 3/4
      # runs, ~1.4 s into the model load; the same model + same node binary
      # work fine via the `qmd` CLI and on a bigger machine, so it is a
      # timing race in the native stack on this box). Force rerank off —
      # which is also the upstream default ("disabled by default to keep
      # MCP queries fast and local-only"). Semantic (vec) + lexical (lex)
      # search are unaffected; reranking remains available via the CLI
      # (set QMD_RERANK_MODEL ad hoc, see qmdLiteEnv below).
      #
      # Patches the TypeScript source: the build runs `tsc`, so the change
      # lands in the shipped dist/mcp/server.js.
        sed -i 's/^        rerank,$/        rerank: false, \/\/ patched by nix: rerank disabled/' src/mcp/server.ts
    '';
    postInstall = ''
      # The npm build hook auto-generates a `node <binfile>` wrapper for
      # the `qmd` bin entry — right for JS entries, wrong here: the
      # repo's bin/qmd is a #!/bin/sh launcher (it picks node vs bun
      # from the lockfile). Replace the wrapper with a symlink to the
      # real script, like an npm global install does: the launcher
      # resolves the package dir by following $0's symlinks, so a
      # plain file at $out/bin/qmd would make it look for dist/cli/
      # qmd.js next to the bin dir instead of in the package dir.
      ln -sf ../lib/node_modules/flowstate-qmd/bin/qmd $out/bin/qmd
      # The launcher execs `node` from PATH — fine inside the hermes
      # service, but NOT in e.g. the NixOS activation environment
      # (127: node: not found). Pin the node binary: this build has
      # package-lock.json, so the launcher always takes the node
      # branch.
      sed -i "s|exec node |exec ${pkgs.nodejs-slim}/bin/node |" $out/lib/node_modules/flowstate-qmd/bin/qmd
    '';
    # Hash of the node_modules tree the lockfile resolves to (the
    # npm-deps FOD). Without it the FOD is unhashable and a clean
    # build (e.g. on skylake during deploy) fails with a hash
    # mismatch; the registry contents for this pinned lockfile are
    # immutable, so the hash is stable.
    npmDepsHash = "sha256-ZSvXA2Huo1YG+Q37y9gKv3dJSMafOmXAaWDW9O6X+sg=";
  };

  # Git-over-ssh for hermes: her only ssh channel is `git push`/`git
  # fetch` to github.com (hermes-github-ssh key below,
  # git@github.com:pmihaly/nix-config), so she can publish the changes
  # she makes in the skylake nix-config checkout. She has no ssh
  # channel to aesop or anywhere else; deploying skylake stays a
  # human-run `make skylake` on aesop.
  #
  # known_hosts lives in the service user's home (the .ssh dir is
  # created by the activation script below).

  # Lite model profile for skylake (2 vCPU / 4 GB). The repo defaults
  # (llm.ts) are Qwen3-Embedding-4B + Qwen3-Reranker-4B plus a 1.7B
  # query-expansion model — far too big for this box. The first two
  # are overridable via env; the expansion model is hardcoded but only
  # loads when the BM25 probe finds no strong lexical signal (rare for
  # short notes). Models are downloaded from HuggingFace at runtime
  # into $HOME/.cache/qmd/models (the hermes user's home is stateDir,
  # on /persist).
  #
  # Reranker (CLI only): the 0.6B Qwen3-Reranker needs a classification
  # (score) head tensor; the mradermacher GGUF is a plain generation
  # quant without it, so node-llama-cpp's createRankingContext fails
  # with "Failed to create any rerank context". The Voodisss GGUF
  # carries the cls.output.weight score head and ranks correctly
  # (verified: 0.9999 vs 0.0001 score separation, ~200 ms/doc). Reranking
  # is patched out of the MCP server (see patchPhase above) and is NOT in
  # this env — for manual CLI reranking add ad hoc:
  #   QMD_RERANK_MODEL="hf:Voodisss/Qwen3-Reranker-0.6B-GGUF-llama_cpp/Qwen3-Reranker-0.6B-Q4_K_M.gguf"
  #
  # NOTE: QMD_EMBED_MODEL must be set on EVERY qmd invocation — without
  # it the 4.28 GB 4B default starts downloading. This env feeds both
  # the MCP server (mcpServers below) and the embed timer.
  qmdLiteEnv = {
    QMD_EMBED_MODEL = "hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf";
    NODE_LLAMA_CPP_GPU = "disable";
  };
in
{
  imports = [
    # The upstream services.hermes-agent option. Importing it here —
    # rather than in a machine's flake module list — keeps this module
    # evaluable on every machine that imports it (modules/nixos pulls it
    # in for all of them). The config below defines services.hermes-agent.*
    # and a definition for an option that doesn't exist breaks evaluation
    # even when mkIf guards it: the module system checks unmatched
    # definitions before it discharges mkIf conditions.
    # Upstream is inert unless services.hermes-agent.enable is set,
    # which we do only under modules.hermes-agent.enable below.
    inputs.hermes-agent.nixosModules.default
  ];

  options.modules.hermes-agent = {
    enable = mkEnableOption "Hermes Agent (Nous Research) — agent gateway + web dashboard";

    qmdMemory = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Expose the agent's notes ($HERMES_HOME/memories) as a
        FlowState-QMD MCP server: semantic (embedding) + lexical
        search over the note files (query/get/status tools).
        Reranking is disabled in the MCP build (native crash on
        skylake, see the patchPhase in qmd above) and stays
        available via the CLI. Lite 0.6B embed model — the repo
        defaults (4B embed/rerank + 1.7B expansion) do not fit
        skylake's 4 GB. Models download to /persist on first use;
        a daily timer re-embeds changed notes.
      '';
    };

    whatsapp = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the WhatsApp platform (self-chat mode): mirrors the
        bridge into HERMES_HOME and sets WHATSAPP_ENABLED in the
        runtime .env, arming the bundled whatsapp-platform adapter.
        See the WhatsApp section in this module for pairing notes.
        Leave off while unpaired — an armed-but-unpaired gateway
        exit-loops with code 78 (harmless but noisy).
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.hermes-agent = {
        enable = true;

        # The `minimal` variant: core app only, without the optional
        # integration groups (matrix, voice, modal, daytona, …) that the
        # default `full` build pulls in. Skylake talks to LLMs over an
        # OpenAI-compatible endpoint (part of the core), so nothing needed
        # is missing. Rebuild-time difference is substantial. Add groups
        # back via `package = ... .override { extraDependencyGroups = [...]; }`
        # if a specific integration (e.g. `messaging`) is ever wanted.
        #
        # `firecrawl` group (firecrawl-py 4.17.0): web search/extract via
        # the bundled firecrawl plugin. Keyless mode (public cloud API,
        # round-robin with exa/parallel/tavily/keenable) works from the
        # core app alone; this group provides the SDK for the keyed
        # path (FIRECRAWL_API_KEY / FIRECRAWL_API_URL) and the lazy
        # `ensure("search.firecrawl")` import path.
        #
        # `matrix` group (mautrix[encryption] 0.21.1): the Matrix gateway
        # adapter (plugins/platforms/matrix/adapter.py) requires mautrix at
        # import time — WITHOUT it check_matrix_requirements() returns False
        # and the channel degrades to stubs. mautrix was verified missing
        # from the deployed hermes-agent-env (task t_991da13d), so `matrix`
        # must be in the group list for the MATRIX_* env vars (below) to take
        # effect. Added alongside this task's credential wiring.
        package = inputs.hermes-agent.packages.${pkgs.stdenv.system}.minimal.override {
          extraDependencyGroups = [ "firecrawl" "matrix" ];
        };

        # LLM backend: OpenRouter (built-in provider), model
        # deepseek/deepseek-v4-flash-0731 (same as pi and opencode on aesop).
        # The old backend — llama-swap on aesop over the tailnet serving
        # Qwen3.8-27B locally — is gone: the local-llm service has been
        # removed entirely, so the model now runs in the cloud. The API key
        # is the agenix secret openrouter-api-key (env-file format, appended
        # to $HERMES_HOME/.env at activation — see environmentFiles below);
        # nothing secret lands in this repo or the Nix store.
        #
        # NOTE on merge direction: the activation script deep-merges these
        # settings INTO the runtime config.yaml with Nix keys winning
        # (nix/configMergeScript.nix). So if you switch models in the
        # dashboard, the next `make skylake` re-asserts the value below.
        # Update `settings` here to change the default model.
        settings = {
          model = {
            default = "deepseek/deepseek-v4-flash-0731";
            provider = "openrouter";
            # Window for the OpenRouter deepseek-v4-flash-0731 backend.
            # The model's real window is 1M; 128k pins the *accounting*
            # to a sane ceiling while giving each turn 3x the headroom of
            # the old 64k pin. The window is NOT the session-size knob
            # anymore: `compression.threshold_tokens` (40k) is an absolute
            # cap that wins over the percent trigger for any window >= ~48k
            # (context_compressor._apply_threshold_tokens_cap — the cap is
            # min(cap, context_length), so it's a no-op here). The summary
            # budget derives from the trigger (40k × 0.20 ≈ 8k), not the
            # window. So compaction fires at 40k whether the window is 64k
            # or 128k — the pin only controls the output headroom left at
            # that moment (~88k vs ~24k), which ends the
            # finish_reason=length truncation class the old 64k window
            # caused.
            #
            # (History: 64000 was the smallest value hermes accepts — agent
            # init rejects below 64k — and matched the old llama.cpp 65k
            # window. With the 40k cap in place, the degenerate-window
            # branch (MINIMUM_CONTEXT_LENGTH floor pinning the percent
            # trigger to 85%) never engages above ~48k, so 128k is fully
            # in the normal branch.)
            context_length = 131072;
          };
          # Retry rounds before a turn gives up with "max compression
          # attempts reached" (the #62605 failure class: incompressible
          # tool schemas keep the estimate above threshold even though
          # the messages compress fine). Default 3 can still be tight
          # when a timed-out attempt burns a round. 10 is the parser's
          # hard cap (agent_init.py clamps anything larger); there is no
          # "unlimited" value in config — that would need an upstream
          # patch.
          #
          # threshold_tokens: the `threshold` PERCENT knob is a ratio of
          # the window (75% for <512k models — see
          # _effective_threshold_percent), which at 128k would defer
          # compaction to ~96k, where a summary+output still fit but the
          # session is huge. threshold_tokens is an ABSOLUTE cap: the
          # effective trigger is min(ratio-threshold, cap). Raised 40k →
          # 90k (2026-09-01, user request) so the long tool-heavy
          # sessions (deploy work) compact ~2.3x less often. At 90k the
          # effective trigger = min(96k, 90k) = 90k, leaving ~38k of the
          # 128k window for the summary + following turns — still clear
          # of finish_reason=length truncation (summary budget = 90k ×
          # 0.20 ≈ 18k). Pushing toward 120k would squeeze that headroom
          # back toward the degenerate-window risk; 90k is the balanced
          # point.
          compression = {
            threshold_tokens = 90000;
            max_attempts = 10;
            # Cheap no-model-call pass: once the session exceeds 85k,
            # truncate stale tool results >8k chars (the main bloat source
            # — file reads, long terminal output). The agent can re-read
            # files / re-run commands, so nothing is truly lost. Raised
            # 35k → 85k to track the new 90k compaction line (2026-09-01).
            # Keeps most prompts under the 90k threshold so the expensive
            # pass (and its max_attempts budget) fires less often. Set to
            # 0 to disable.
            proactive_prune_tokens = 85000;
          };
          # Web search/extract backend. Explicit config wins over the
          # availability-filtered legacy walk (agent/web_search_registry.py),
          # which — with no FIRECRAWL_API_KEY — would otherwise only let
          # firecrawl join the 5-vendor keyless round-robin (~1/5 of traffic).
          # Pinned: today it serves via the keyless public cloud API
          # (raw httpx, no SDK), failing over to exa/parallel/tavily on
          # rate limits; once FIRECRAWL_API_URL/FIRECRAWL_API_KEY exist in
          # $HERMES_HOME/.env, _use_keyless_ring() flips to false and the
          # keyed firecrawl-py SDK path (installed via the `firecrawl`
          # dependency group above) takes over automatically.
          web = {
            backend = "firecrawl";
          };
          # Matrix verbosity: only show final results in chat, not the
          # intermediate tool-call bubbles / mid-turn commentary / heartbeat
          # messages. tool_progress=off kills the per-tool "[terminal] ran…"
          # stream; interim_assistant_messages=false drops mid-turn
          # "Let me check…" commentary; long_running_notifications=false drops
          # the "⏳ Working — N min" heartbeat.
          display = {
            platforms = {
              matrix = {
                tool_progress = "off";
                interim_assistant_messages = false;
                long_running_notifications = false;
              };
            };
          };
        };

        # ── WhatsApp ────────────────────────────────────────────────
        # whatsapp (option above) arms the bundled whatsapp-platform
        # adapter: WHATSAPP_ENABLED lands in $HERMES_HOME/.env, which
        # the gateway reads. The defaults do the rest safely:
        #   - mode stays "self-chat" (the agent links YOUR WhatsApp
        #     account — no second/bot number needed),
        #   - DM and group policy default to "pairing": nobody can
        #     reach the agent until paired through the dashboard.
        #
        # While enabled but UNPAIRED the gateway exits 78 and systemd
        # restarts it in a loop (harmless — the dashboard runs in the
        # separate backend service — but noisy), so flip this off
        # again if you want a clean slate (also wipe the session dir
        # under $HERMES_HOME/platforms/whatsapp to forget the creds).
        #
        # Gotcha when turning it OFF: the upstream state script only
        # writes .env when environment/environmentFiles are non-empty
        # (moduleCommon.nix, mkStateScript), so a stale
        # WHATSAPP_ENABLED=true line SURVIVES a deploy and the plugin
        # stays armed. Remove the line from $HERMES_HOME/.env and
        # restart the gateway as part of the shutdown.
        #
        # extraPackages puts the bridge tree (above) into the system
        # closure for the activation script; the derivation has no
        # bin/, so nothing lands on the hermes user's PATH.
        # Matrix operator allowlist (plaintext setting — NOT a secret).
        # Both the gateway governance gate (startup warning: "No env user
        # allowlists configured … will deny unknown senders") and the matrix
        # adapter's trigger gate check the sender against MATRIX_ALLOWED_USERS
        # (full "@user:server" form). Without it every sender — including the
        # operator @misi — is rejected as "unauthorized user" and the channel
        # is inert. mautrix must be present for the adapter to load at all
        # (the `matrix` dependency group above).
        #
        # MATRIX_E2EE_MODE enables Matrix end-to-end encryption (olm/megolm).
        # The adapter defaults to OFF; "optional" turns on the OlmMachine so
        # the bot decrypts incoming encrypted events and auto-encrypts its
        # replies in encrypted rooms (mautrix 0.21 auto-encrypts outgoing
        # when room state requests it, after share_keys). "required" is the
        # same but hard-fails the whole channel if crypto init or device-key
        # verification fails at connect; "optional" degrades to plaintext
        # instead of bricking the bridge — the right choice here since the
        # operator's own @misi room may be plaintext. Deps (mautrix
        # [encryption] group, python-olm, aiosqlite, PgCryptoStore sqlite
        # backend) are bundled via the `matrix` group above, so optional
        # actually engages. MATRIX_DEVICE_ID is deliberately NOT set: unset,
        # the adapter uses the login token's own device_id, which is stable
        # (the token persists) and keyed in the SQLite crypto store at
        # $HERMES_HOME/platforms/matrix/store/crypto.db — forcing a different id
        # would reset the Olm identity and force re-verification.
        # NOTE: the gateway reads .env into its process env at startup, so a
        # gateway (re)start is required for this to take effect.
        environment =
          (optionalAttrs cfg.whatsapp {
            WHATSAPP_ENABLED = "true";
          })
          // {
            MATRIX_ALLOWED_USERS = "@misi:matrix.skylake.mihaly.codes";
            MATRIX_E2EE_MODE = "optional";
          };

        # OpenRouter API key + Matrix bot credentials (agenix; env-snippet
        # format, OPENROUTER_API_KEY=… / MATRIX_HOMESERVER=… etc).
        # environmentFiles are appended to $HERMES_HOME/.env at ACTIVATION
        # time (mkEnvScript cats each file in), so the keys never land in the
        # Nix store — only the .age files in secrets/ are committed. Hermes'
        # built-in openrouter provider reads OPENROUTER_API_KEY from
        # $HERMES_HOME/.env at startup (credential_pool.py prefers the dotenv
        # over the service env); the matrix adapter reads the MATRIX_* vars
        # the same way (requires the `matrix` group — see package above).
        environmentFiles = [
          config.age.secrets."openrouter-api-key".path
          config.age.secrets."matrix-bot".path
        ];
        extraPackages =
          (optional cfg.whatsapp whatsappBridge)
          # QMD: the CLI on PATH (for `qmd embed` in the timer and for
          # ad-hoc use). The node binary is pinned inside the derivation
          # (see the postInstall above), so no PATH dependency; node
          # stays on the service PATH anyway for ad-hoc use.
          ++ (optional cfg.qmdMemory qmd)
          ++ (optional cfg.qmdMemory pkgs.nodejs-slim)
          # The agent edits the nix-config checkout on skylake (group
          # `nixcfg`, machines/skylake). Explicit rather than relying on
          # the transitive dep the package pulls in today, so an upstream
          # bump can't silently break that.
          # The ssh client for the GitHub push (and ad-hoc tailnet use).
          ++ [
            pkgs.git
            pkgs.openssh
          ];

        # ── QMD notes search (MCP) ────────────────────────────────────
        # Registers FlowState-QMD as a stdio MCP server the gateway
        # spawns; the agent gains `query`, `get`/`multi_get`, `status`
        # (and `fetch_anticipatory_context`) tools over the
        # `hermes-memories` collection, which the activation script
        # below points at $HERMES_HOME/memories — the directory the
        # built-in memory tool writes to. MEMORY.md/USER.md stay fully
        # in-context via the normal system prompt; QMD adds search over
        # the additional note files the agent accumulates there.
        #
        # Steady-state cost: the MCP child process holds the ~0.7 GB
        # embed model in RAM once the first query loads it. Reranking
        # is compiled out of the MCP build (see the qmd patchPhase),
        # so no second model ever loads in that process. The daily
        # re-embed runs as a separate short-lived process, so that
        # cost is transient.
        mcpServers = optionalAttrs cfg.qmdMemory {
          qmd = {
            command = "${qmd}/bin/qmd";
            args = [ "mcp" ];
            env = qmdLiteEnv;
          };
        };

        # State on /persist: skylake's root is tmpfs (impermanence), so the
        # module's default /var/lib/hermes would vanish on every reboot.
        # vars.serviceConfig is already in the restic backup list
        # (modules-v2/nixos/backup via machines/skylake).
        stateDir = "${vars.serviceConfig}/hermes";
        # workingDirectory stays the module default: ${stateDir}/workspace.

        backend = {
          # The browser dashboard (the web UI) on 9119.
          mode = "dashboard";

          # Loopback bind => the dashboard's auth gate stays OFF (no login
          # page, single-user by construction). should_require_dashboard_auth()
          # in web_server.py only engages the gate for non-loopback binds or
          # a configured dashboard.public_url; --insecure can no longer
          # disable it, so loopback is the only gate-free mode.
          #
          # Tailnet access comes through nginx instead: the /hermes
          # location on the ts.net vhost (below) proxies to this port with
          #   - Host rewritten to 127.0.0.1  (the dashboard's Host-header
          #     guard only accepts loopback names for loopback binds),
          #   - Origin dropped               (the WS Origin guard treats a
          #     missing Origin as allowed),
          #   - X-Forwarded-Prefix: /hermes  (the prefix-aware SPA rewrites
          #     its own asset URLs; see mount_spa() in web_server.py).
          # The app sees nginx as a 127.0.0.1 peer, so the WS loopback-peer
          # check passes too (uvicorn proxy_headers stays off without the
          # gate, so X-Forwarded-For can't defeat it).
          host = "127.0.0.1";
          inherit port;
        };
      };

      # GitHub SSH key for hermes (git push/fetch over ssh): "skylake's
      # key" — the mihaly@mihaly.codes keypair, which is also skylake's
      # ssh HOST key (machines/skylake persists it at
      # /persist/etc/ssh/ssh_host_ed25519_key; secrets/secrets.nix lists
      # the same pubkey under both names) and is registered on GitHub as
      # pmihaly. Materialized at the default
      # /run/agenix/server/hermes-github-ssh (400, hermes-owned), decrypted
      # on skylake via the host-key identity. The ssh client config
      # that points git at it lives in the activation script below.
      age.secrets."server/hermes-github-ssh" = {
        file = ../../../secrets/server/hermes-github-ssh.age;
        owner = hermesCfg.user;
        group = hermesCfg.group;
        mode = "400";
      };

      # OpenRouter API key (see environmentFiles above). Materialized at the
      # default /run/agenix/openrouter-api-key, readable only by the hermes
      # user. Env-file format because the activation script appends the raw
      # file content to $HERMES_HOME/.env.
      age.secrets."openrouter-api-key" = {
        file = ../../../secrets/openrouter-api-key.age;
        owner = hermesCfg.user;
        group = hermesCfg.group;
        mode = "400";
      };

      # Matrix bot credentials (env-file: MATRIX_HOMESERVER,
      # MATRIX_BOT_USER, MATRIX_ACCESS_TOKEN, MATRIX_HOME_ROOM — and
      # MATRIX_BOT_PASSWORD if a password login is used). Same
      # env-file format as openrouter above; the matrix adapter reads it
      # from $HERMES_HOME/.env (appended via environmentFiles above).
      age.secrets."matrix-bot" = {
        file = ../../../secrets/matrix-bot.age;
        owner = hermesCfg.user;
        group = hermesCfg.group;
        mode = "400";
      };

      # known_hosts dir for hermes' ssh client (UserKnownHostsFile
      # points at the service user's home, so accept-new can pin
      # github.com's host key on hermes's first push).
      system.activationScripts."hermes-ssh" = {
        deps = [ "users" ];
        text = ''
          mkdir -p ${hermesCfg.stateDir}/.ssh
          chown ${hermesCfg.user}:${hermesCfg.group} ${hermesCfg.stateDir}/.ssh
          chmod 700 ${hermesCfg.stateDir}/.ssh
        '';
      };

      # Git-over-ssh for hermes: pin GitHub to the hermes-github-ssh key
      # (agenix secret above) via hermes' ~/.ssh/config. HOME is the
      # service user's stateDir (upstream sets it on every hermes unit), so
      # ssh reads this config for every `git push`/`git fetch` hermes runs.
      # known_hosts is the file "hermes-ssh" created; github.com's
      # host key is pinned on first use (accept-new). BatchMode keeps
      # pushes non-interactive.
      system.activationScripts."hermes-github-ssh" = {
        deps = [
          "users"
          "hermes-ssh"
        ];
        text = ''
          ssh_dir=${hermesCfg.stateDir}/.ssh
          cat > "$ssh_dir/config" <<'EOF'
          Host github.com
            IdentityFile /run/agenix/server/hermes-github-ssh
            IdentitiesOnly yes
            UserKnownHostsFile ${hermesCfg.stateDir}/.ssh/known_hosts
            StrictHostKeyChecking accept-new
            BatchMode yes
          EOF
          chmod 600 "$ssh_dir/config"
          chown ${hermesCfg.user}:${hermesCfg.group} "$ssh_dir/config"
        '';
      };

      # Pre-populate the WhatsApp bridge mirror in HERMES_HOME (see
      # whatsappBridge above). deps: "users" — the chown needs the
      # hermes user; "hermes-agent-setup" — the upstream script that
      # creates $HERMES_HOME and writes .env. Re-copied on every
      # switch, so a hermes-agent input bump refreshes the bridge
      # (node_modules/ is created at runtime by `npm install` and
      # survives the copy; the bridge's script-hash check makes the
      # gateway restart a running bridge when the code changes).
      # Only present when whatsapp is on; the existing mirror on disk
      # is left alone when it is turned off again (harmless — the
      # plugin does not load without WHATSAPP_ENABLED).
      system.activationScripts."hermes-whatsapp-bridge" = mkIf cfg.whatsapp {
        deps = [
          "users"
          "hermes-agent-setup"
        ];
        text = ''
          mkdir -p ${hermesHome}/scripts
          cp -rT ${whatsappBridge} ${hermesHome}/scripts/whatsapp-bridge
          chown -R ${hermesCfg.user}:${hermesCfg.group} ${hermesHome}/scripts
          chmod -R u+rwX ${hermesHome}/scripts/whatsapp-bridge
        '';
      };

      # Register the QMD notes collection once (idempotent across
      # deploys). Runs as the hermes user so ~/.config/qmd and
      # ~/.cache/qmd are owned by the service user. `collection add`
      # does not load any model, so this stays fast and works offline;
      # the model download + first embed happen on the first
      # `qmd embed` (see the timer below) or the first MCP query.
      system.activationScripts."hermes-qmd-memory" = mkIf cfg.qmdMemory {
        deps = [
          "users"
          "hermes-agent-setup"
        ];
        # NOTE: no backslash line-continuations in this text — the
        # activation-script rendering escapes them to `\\`, which the
        # shell then passes to env as a literal `\\` argument
        # ("env: '\\': No such file or directory").
        text = ''
          mkdir -p ${hermesHome}/memories
          chown ${hermesCfg.user}:${hermesCfg.group} ${hermesHome}/memories
          # qmd keeps its config in $HOME/.config/qmd and its index
          # databases + model cache in $HOME/.cache/qmd. Ensure the
          # service user owns the XDG dirs — they are root-owned when
          # the models were pre-staged out-of-band (as on skylake),
          # which makes the DB open fail with SQLITE_CANTOPEN.
          mkdir -p ${hermesCfg.stateDir}/.config/qmd ${hermesCfg.stateDir}/.cache/qmd
          chown ${hermesCfg.user}:${hermesCfg.group} ${hermesCfg.stateDir}/.config ${hermesCfg.stateDir}/.config/qmd ${hermesCfg.stateDir}/.cache ${hermesCfg.stateDir}/.cache/qmd
          QMD_COLLECTIONS=$(runuser -u ${hermesCfg.user} -- env HOME=${hermesCfg.stateDir} ${qmd}/bin/qmd collection list 2>/dev/null)
          if ! printf '%s' "$QMD_COLLECTIONS" | grep -q hermes-memories; then
            runuser -u ${hermesCfg.user} -- env HOME=${hermesCfg.stateDir} ${qmd}/bin/qmd collection add ${hermesHome}/memories --name hermes-memories
          fi
        '';
      };

      # Refresh the notes index daily as a short-lived separate
      # process (the models are released on exit), keeping QMD's
      # steady-state RAM in the gateway's MCP child only. Persistent +
      # randomised so a box that was off at the scheduled time catches
      # up after boot.
      #
      # Both steps are needed: `update` re-scans the collection for
      # new/changed/deleted files (collection add only does this once,
      # and the MCP `query` tool never re-indexes), `embed` then
      # embeds whatever changed.
      systemd.services."hermes-qmd-embed" = mkIf cfg.qmdMemory {
        description = "Hermes QMD: re-index + re-embed notes";
        path = [
          qmd
          pkgs.nodejs-slim
          pkgs.coreutils
        ];
        environment = qmdLiteEnv // {
          HOME = hermesCfg.stateDir;
        };
        script = "${qmd}/bin/qmd update && ${qmd}/bin/qmd embed";
        serviceConfig = {
          User = hermesCfg.user;
          Group = hermesCfg.group;
          WorkingDirectory = hermesCfg.stateDir;
        };
      };

      systemd.timers."hermes-qmd-embed" = mkIf cfg.qmdMemory {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "30min";
          Persistent = true;
        };
      };
    }

    {
      # Internal-only exposure: the ts.net vhost is served on public 80,
      # so the location is restricted to tailnet source addresses
      # (100.64.0.0/10) at the nginx layer.
      # Two locations, and the trailing slash in the second one is LOAD
      # BEARING: when proxy_pass has a URI part, nginx strips exactly the
      # location NAME from the request URI (src/http/modules/
      # ngx_http_proxy_module.c: loc_len = min(location.len, uri.len)) and
      # then prepends the proxy_pass URI. So:
      #   location /hermes  + proxy_pass http://…9119/;  ->  //assets/…
      #   location /hermes/ + proxy_pass http://…9119/;  ->  /assets/…
      # The double slash is not matched by the app's /assets static mount
      # and falls into the SPA catch-all, which serves index.html for
      # every request (blank white page). Verified against nginx 1.30.4
      # source and by strace.
      services.nginx.virtualHosts."${vars.domainName}".locations = {
        # Without this exact match, a bare /hermes would fall into the
        # vhost's `location /` (301 to /homer…).
        "= /hermes" = {
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
            return 301 /hermes/;
          '';
        };

        "/hermes/" = {
          # proxy_pass WITH a URI ("/") strips the /hermes/ prefix:
          # /hermes/api/x -> /api/x, which is what the app routes on.
          # (The X-Forwarded-Prefix header is only used to rewrite the
          # served SPA's asset URLs, not for routing.)
          proxyPass = "http://127.0.0.1:${toString port}/";
          proxyWebsockets = true;

          # The recommended proxy settings are `include`d AFTER extraConfig
          # in the generated config and would reset Host to $host,
          # overriding the rewrite the loopback Host-guard requires — so
          # disable them and set the headers manually.
          recommendedProxySettings = false;

          extraConfig = ''
            # Tailnet-only (see above).
            allow 100.64.0.0/10;
            deny all;

            # Must match a loopback name for the dashboard's Host-header
            # guard (DNS-rebinding protection).
            proxy_set_header Host 127.0.0.1;
            # Empty value => nginx omits the header; the WS Origin guard
            # accepts a missing Origin.
            proxy_set_header Origin "";
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            # Tells the SPA to serve assets under /hermes (mount_spa()).
            proxy_set_header X-Forwarded-Prefix /hermes;

            # Agent runs / LLM calls can be long; don't cut them off.
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };

        # The SPA's dynamic chunks (its xterm/terminal module) request bare
        # /assets/* — absolute paths baked into the JS bundle by Vite, NOT
        # rewritten by the X-Forwarded-Prefix HTML mount (that only rewrites
        # <script>/<link> tags in index.html). Without this location, a bare
        # /assets/xterm-*.css falls into the vhost's catch-all `location /`
        # (301 -> /homer/... -> 301 http://:8080 -> mixed-content block) and
        # the chat view never mounts (blank page). The backend serves /assets/*
        # directly at / on port 9119, so proxy it the same way as /hermes/.
        "/assets/" = {
          # NOTE: proxy_pass has NO URI part here (vs /hermes/ which uses
          # "…9119/"). A trailing-slash proxy_pass would STRIP the /assets/
          # prefix (the documented trap above) and send /assets/xterm.css as
          # /xterm.css — which the backend treats as an unknown path and
          # serves the SPA index.html (HTTP 200, wrong content-type). Passing
          # the URI verbatim (no slash) keeps /assets/xterm-*.css intact, which
          # the backend's static mount serves correctly.
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = false;

          # Same Host-header rewrite the /hermes/ location uses, so the
          # loopback DNS-rebinding guard accepts these requests too.
          recommendedProxySettings = false;

          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
            proxy_set_header Host 127.0.0.1;
            proxy_set_header Origin "";
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            # The SPA loads the xterm chunk via a <link rel=preload
            # crossOrigin=...> (react-vendor's runtime preload sets
            # i.crossOrigin=""), which forces a CORS-mode request even
            # though the URL is same-origin. Without ACAO the preload
            # fires 'error' -> "Unable to preload CSS". * is fine here:
            # this tailnet-only vhost serves no credentialed data.
            add_header Access-Control-Allow-Origin * always;
          '';
        };
      };

      # Card on the private Homer board.

      modules.homer.services.AI.Hermes = {
        logo = ./hermes.png;
        url = "http://${vars.domainName}/hermes/";
      };
    }
    {
      # Grant the hermes agent shell read-write access to the synced folder
      # (the ACLs/group cover the host; this exposes the same path rw INSIDE
      # the agent's sandbox (ProtectSystem=strict whitelists ReadWritePaths).
      # The upstream unit defaults the list to hermes' own dirs; this concat-merges
      # (systemd option of list-of-str concatenates across modules) adding the sync root.
      systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [
        "/persist/opt/skylake-storage/syncthing"
      ];
      # Same for the hermes-backend unit, which is what the file/terminal tools
      # actually execute under (the backend spawns the tool shell). Without this,
      # the backend sees /persist read-only (ProtectSystem=strict) and file edits
      # fail with "Read-only file system", even though the agent process itself
      # has the rw bind from the grant above. Keep it narrow to the sync tree.
      systemd.services.hermes-backend.serviceConfig.ReadWritePaths = [
        "/persist/opt/skylake-storage/syncthing"
      ];
    }
  ]);
}
