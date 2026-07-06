{
  platform,
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

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    users.users.llama-cpp = {
      isSystemUser = true;
      group = "llama-cpp";
      extraGroups = [ "video" ];
    };

    users.groups.llama-cpp = { };

    users.users.open-webui = {
      isSystemUser = true;
      group = "open-webui";
    };

    users.groups.open-webui = { };

    users.users.searxng = {
      isSystemUser = true;
      group = "searxng";
    };

    users.groups.searxng = { };

    environment.persistence.${vars.persistDir}.directories = [
      "/var/cache/llama-cpp"
      "/var/lib/llama-cpp"
      "/var/lib/open-webui"
      "/var/lib/searxng"
    ];

    systemd.tmpfiles.rules = [
      "d /var/cache/llama-cpp 0755 llama-cpp llama-cpp -"
      "d /var/lib/llama-cpp 0755 llama-cpp llama-cpp -"
      "d /var/lib/open-webui 0755 open-webui open-webui -"
      "d /var/lib/searxng 0755 searxng searxng -"
    ];

    systemd.services.searxng = {
      description = "SearXNG search engine";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "exec";
        User = "searxng";
        Group = "searxng";
        ExecStart = "${pkgs.searxng}/bin/searxng-run";
        WorkingDirectory = "/var/lib/searxng";
        Environment = [
          "SEARXNG_PORT=8888"
          "SEARXNG_BIND_ADDRESS=127.0.0.1"
          "SEARXNG_SECRET=searxng-secret-${vars.username}"
        ];
        StateDirectory = "searxng";
      };
      wantedBy = [ "multi-user.target" ];
    };

    services.llama-swap = {
      enable = true;
      settings = {
        healthCheckTimeout = 60;
        logToStdout = "both";
        globalTTL = 0;
        sendLoadingState = true;
        models."Qwen3.6-27B Q4 +MTP" = {
          name = "Qwen3.6-27B Q4 +MTP";
          cmd =
            "${pkgs.llama-cpp-rocm}/bin/llama-server --host 0.0.0.0 --port "
            + "$"
            + "{PORT} --models-preset ${
              (pkgs.formats.ini { }).generate "models.ini" {
                "Qwen3.6-27B Q4 +MTP" = {
                  "hf-repo" = "unsloth/Qwen3.6-27B-MTP-GGUF";
                  "hf-file" = "Qwen3.6-27B-Q4_K_M.gguf";
                  "spec-type" = "draft-mtp";
                  ngl = "all";
                  fa = "on";
                  "cache-type-k" = "q4_0";
                  "cache-type-v" = "q4_0";
                  "fit-target" = 19000;
                  "ctx-size" = 32768;
                  "ubatch-size" = 1024;
                  "batch-size" = 2048;
                  "cache-reuse" = 256;
                  parallel = 1;
                };
              }
            }";
          checkEndpoint = "/health";
          ttl = 0;
        };
        models."Qwen3-4B Q4" = {
          name = "Qwen3-4B Q4";
          cmd =
            "${pkgs.llama-cpp-rocm}/bin/llama-server --host 0.0.0.0 --port "
            + "$"
            + "{PORT} --models-preset ${
              (pkgs.formats.ini { }).generate "small.ini" {
                "Qwen3-4B Q4" = {
                  "hf-repo" = "unsloth/Qwen3-4B-GGUF";
                  "hf-file" = "Qwen3-4B-Q4_K_M.gguf";
                  ngl = "all";
                  fa = "on";
                  "cache-type-k" = "q4_0";
                  "cache-type-v" = "q4_0";
                  "fit-target" = 3000;
                  "ctx-size" = 32768;
                  "ubatch-size" = 1024;
                  "batch-size" = 2048;
                  "cache-reuse" = 256;
                  parallel = 1;
                };
              }
            }";
          checkEndpoint = "/health";
          ttl = 0;
        };
      };
    };

    systemd.services.llama-swap.serviceConfig = {
      DynamicUser = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      ProtectSystem = lib.mkForce "false";
      User = "llama-cpp";
      Group = "llama-cpp";
      Environment = [ "LLAMA_CACHE=/var/cache/llama-cpp" ];
    };

    services.open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = 3000;
      stateDir = "/var/lib/open-webui";
      environment = {
        OLLAMA_BASE_URL = "http://127.0.0.1:8080/v1";
        OLLAMA_API_BASE_URL = "http://127.0.0.1:8080";
        OPENAI_API_BASE_URL = "http://127.0.0.1:8080/v1";
        OPENAI_API_KEY = "local";
        # Override default "http://localhost:PORT" so API calls use relative URLs
        WEBUI_URL = "";
        SEARXNG_API_URL = "http://127.0.0.1:8888";
      };
    };

    systemd.services.open-webui.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "open-webui";
      Group = "open-webui";
    };

    home-manager.users.${vars.username} = {
      home.packages = [ pkgs.docker-compose ];

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
          provider.llama = {
            name = "llama.cpp (local)";
            npm = "@ai-sdk/openai-compatible";
            options = {
              baseURL = "http://127.0.0.1:8080/v1";
              apiKey = "local";
            };
            models."Qwen3.6-27B Q4 +MTP".name = "Qwen3.6-27B Q4 +MTP";
            models."Qwen3-4B Q4".name = "Qwen3-4B Q4";
          };
        };
        agents = {
          architect = ''
            ---
            description: System architecture and design decisions
            mode: subagent
            model: llama/Qwen3.6-27B Q4 +MTP
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
            model: llama/Qwen3.6-27B Q4 +MTP
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
            model: llama/Qwen3.6-27B Q4 +MTP
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
            model: llama/Qwen3.6-27B Q4 +MTP
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

      modules.persistence.directories = [
        ".config/aws"
        ".local/share/docker"
        ".config/opencode"
        ".local/share/opencode"
        ".local/state/opencode"
      ];
    };
  };
}
