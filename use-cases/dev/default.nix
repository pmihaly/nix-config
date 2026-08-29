{
  platform,
  inputs,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.dev;
in
optionalAttrs platform.isLinux {
  options.modules.dev = {
    enable = mkEnableOption "dev";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable {
    # local-llm (llama-swap + Open WebUI + SearXNG on aesop) is DISABLED:
    # the local Qwen3.8-27B backend was the point of the module, and
    # running it is what we wanted to stop (power). Its consumers now use
    # OpenRouter instead — hermes (skylake, see
    # modules/nixos/hermes-agent) and pi/opencode below (same model,
    # qwen/qwen3.8-27b, hosted). Re-enable to bring the local stack back;
    # the module itself is unchanged.
    # modules.local-llm.enable = true;

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    home-manager.users.${vars.username} = {
      home.packages = [
        pkgs.docker-compose
        pkgs.docker-compose
        pkgs.pi-coding-agent
        inputs.boxes.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.cr.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      programs.opencode = {
        enable = true;
        context = ''
          ## Behavior
          - Concise. No preamble. No guessed URLs. Never commit unless asked.
          - Use `nix-shell -p <pkg> --run "<cmd>"` for all tool invocations.
          - Run lint/typecheck before completing work.

          ## Code
          - Follow existing conventions. Write the simplest code possible. No new symbols unless required.
          - Keep interfaces small; push complexity to implementation. Few deep methods over many shallow ones.
          - Provide sensible defaults so parameters disappear for the common case.
          - Vertical slices by business terms. Max 1 level of nesting. No `else` — early returns. Immutable by default.

          ## API Design
          - Make illegal states unrepresentable. Prefer total functions and idempotent operations.
          - Use types to eliminate invalid states at compile time. Absorb rare cases into the common case.
          - Hide implementation details. Name for meaning, not mechanism. Question every parameter.

          ## Error Handling
          - No silent fallbacks: no bare `??`, `||`, empty `catch {}`, or `return null`.
          - First design errors out of existence. If unavoidable, handle explicitly and visibly.
          - Fail loudly with context. Never swallow errors without logging.
        '';
        settings = {
          server = {
            port = 4096;
            hostname = "0.0.0.0";
          };
          # Qwen via OpenRouter (the local llama-swap backend on aesop is
          # gone — local-llm disabled to save power). Same model as before
          # (qwen/qwen3.8-27b), now hosted. The key comes from the
          # environment: opencode interpolates {env:…} in provider options,
          # and OPENROUTER_API_KEY is exported by programs.bash below from
          # the agenix secret. The models map key must be the real
          # OpenRouter model id (that is what goes in the API request), so
          # the agent references below are provider/key =
          # qwen/qwen/qwen3.8-27b.
          provider.qwen = {
            name = "Qwen (OpenRouter)";
            npm = "@ai-sdk/openai-compatible";
            options = {
              baseURL = "https://openrouter.ai/api/v1";
              apiKey = "{env:OPENROUTER_API_KEY}";
            };
            models."qwen/qwen3.8-27b".name = "Qwen3.8-27B (OpenRouter)";
          };
        };
        agents = {
          architect = ''
            ---
            description: System architecture and design decisions
            mode: subagent
            model: qwen/qwen/qwen3.8-27b
            temperature: 0.2
            permission:
              edit: deny
              bash:
                "*": deny
                "nix *": allow
                "git *": allow
            ---
            You are an architect agent. Analyze requirements, design system architecture, and make high-level technical decisions.

            ## Behavior
            - Concise. No preamble. No guessed URLs. Never commit unless asked.

            ## API Design
            - Make illegal states unrepresentable. Prefer total functions and idempotent operations.
            - Use types to eliminate invalid states at compile time. Absorb rare cases into the common case.
            - Hide implementation details. Name for meaning, not mechanism. Question every parameter.

            Focus on:
            - System structure and module boundaries
            - Tradeoffs between alternatives
            - Error handling strategy
            - Data flow and dependencies

            Provide concrete, actionable plans. Question assumptions and surface hidden complexity.
          '';
          coder = ''
            ---
            description: Implementation and code writing
            mode: subagent
            model: qwen/qwen/qwen3.8-27b
            temperature: 0.1
            ---
            You are a coder agent. Implement features, fix bugs, and write clean code.

            ## Behavior
            - Concise. No preamble. No guessed URLs. Never commit unless asked.
            - Use `nix-shell -p <pkg> --run "<cmd>"` for all tool invocations.
            - Run lint/typecheck before completing work.

            ## Code
            - **very important** Vertical slices by business terms. Max 1 level of nesting. No `else` — early returns. Immutable by default.
            - Dont write comments
            - Follow existing conventions. Write the simplest code possible. No new symbols unless required.
            - Keep interfaces small; push complexity to implementation. Few deep methods over many shallow ones.
            - Provide sensible defaults so parameters disappear for the common case.

            ## Error Handling
            - No silent fallbacks: no bare `??`, `||`, empty `catch {}`, or `return null`.
            - First design errors out of existence. If unavoidable, handle explicitly and visibly.
            - Fail loudly with context. Never swallow errors without logging.

            Run relevant tests or lint commands after making changes.
          '';
          researcher = ''
            ---
            description: Codebase exploration and research
            mode: subagent
            model: qwen/qwen/qwen3.8-27b
            temperature: 0.1
            permission:
              edit: deny
              write: deny
              bash:
                "*": deny
                "nix *": allow
                "git *": allow
            ---
            You are a researcher agent. Explore codebases, find relevant code, and understand how things work.

            ## Behavior
            - Concise. No preamble. No guessed URLs. Never commit unless asked.

            Focus on:
            - Finding the right files and functions
            - Understanding existing patterns and conventions
            - Tracing data flow and dependencies
            - Summarizing findings concisely

            Return specific file paths, line numbers, and code snippets. Verify everything in the actual code.
          '';
          tester = ''
            ---
            description: Writing and running tests
            mode: subagent
            model: qwen/qwen/qwen3.8-27b
            temperature: 0.1
            ---
            You are a tester agent. Write tests and verify code correctness.

            ## Behavior
            - Concise. No preamble. No guessed URLs. Never commit unless asked.
            - Use `nix-shell -p <pkg> --run "<cmd>"` for all tool invocations.

            ## Code
            - Follow existing conventions. Write the simplest code possible. No new symbols unless required.
            - Max 1 level of nesting. No `else` — early returns. Immutable by default.

            ## Error Handling
            - No silent fallbacks: no bare `??`, `||`, empty `catch {}`, or `return null`.
            - Test error paths explicitly. Fail loudly with context.

            Focus on:
            - Writing focused, single-purpose tests
            - Covering edge cases and error paths
            - Following existing test patterns
            - Running tests to verify they pass

            Keep tests simple and readable. Mirror the style of existing tests.
          '';
        };
      };

      home.file = {
        ".pi/agent/extensions/ntfy-notify.ts" = {
          force = true;
          source = ./pi/ntfy-notify.ts;
        };

        # pi's (pi-mono) models.json: upserts qwen/qwen3.8-27b into pi's
        # BUILT-IN openrouter provider. Per docs/models.md, a models array
        # under an existing provider merges — the built-in catalog stays,
        # this model is added by id. (The bundled catalog is generated at
        # build time and predates qwen3.8-27b, so it must be declared.)
        # Auth is the built-in behaviour: the openrouter provider reads
        # OPENROUTER_API_KEY from the environment, which programs.bash
        # below exports from the agenix secret. Same session envelope as
        # the old local llama-swap setup (65536/8192) so behaviour is
        # unchanged; OpenRouter itself allows up to 1M context.
        ".pi/agent/models.json" = {
          force = true;
          text = toJSON {
            providers.openrouter.models = [
              {
                id = "qwen/qwen3.8-27b";
                name = "Qwen3.8-27B (OpenRouter)";
                reasoning = true;
                input = [ "text" ];
                contextWindow = 65536;
                maxTokens = 8192;
                # $/M tokens from the OpenRouter /models API (2025-08):
                # prompt $0.425, completion $2.55 (no cache pricing).
                cost = {
                  input = 0.425;
                  output = 2.55;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
              }
            ];
          };
        };

        ".pi/agent/settings.json" = {
          force = true;
          text = toJSON {
            defaultProvider = "openrouter";
            defaultModel = "qwen/qwen3.8-27b";
            theme = "dark";
            lastChangelogVersion = pkgs.pi-coding-agent.version;
          };
        };
      };

      # ── OpenRouter secret (agenix, user level) ────────────────────
      # The same .age hermes uses (secrets/openrouter-api-key.age),
      # materialized by the agenix user service (agenix.service, WantedBy
      # default.target) into $XDG_RUNTIME_DIR/agenix/openrouter-api-key
      # (0400, user-owned) at every login. pi and opencode read
      # OPENROUTER_API_KEY from the environment; the export below wires
      # the two together.
      #
      # identityPaths MUST be set explicitly: the module default
      # (~/.ssh/id_ed25519 + ~/.ssh/id_rsa) matches no key on this machine
      # (the key is ~/.ssh/mihaly@mihaly.codes) — with the default,
      # user-level agenix can't decrypt ANY secret (the email one included;
      # its mount dir was silently empty until this fix).
      age = {
        identityPaths = [
          "${config.users.users.${vars.username}.home}/.ssh/mihaly@mihaly.codes"
        ];
        secrets."openrouter-api-key" = {
          file = ../../secrets/openrouter-api-key.age;
          mode = "0400";
        };
      };

      programs.bash.initExtra = ''
        # OPENROUTER_API_KEY for pi / opencode / anything else that reads
        # it from the environment. The agenix user service materializes
        # the secret into $XDG_RUNTIME_DIR/agenix at login; the file is an
        # env snippet (OPENROUTER_API_KEY=…), so sourcing it sets the
        # variable. Silent no-op when it is not (yet) materialized — e.g.
        # a shell started before the user service ran.
        if [ -r "${"$"}XDG_RUNTIME_DIR/agenix/openrouter-api-key" ]; then
          . "${"$"}XDG_RUNTIME_DIR/agenix/openrouter-api-key"
          export OPENROUTER_API_KEY
        fi
      '';

      modules.persistence.files = [
        ".pi/agent/auth.json"
        ".pi/agent/models-store.json"
      ];

      modules.persistence.directories = [
        ".config/aws"
        ".local/share/docker"
        ".config/opencode"
        ".local/share/opencode"
        ".local/state/opencode"
        ".pi/agent/sessions"
      ];
    };
  };
}
