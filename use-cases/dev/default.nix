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

    environment.persistence.${vars.persistDir}.directories = [
      "/var/cache/llama-cpp"
      "/var/lib/llama-cpp"
    ];

    systemd.tmpfiles.rules = [
      "d /var/cache/llama-cpp 0755 llama-cpp llama-cpp -"
      "d /var/lib/llama-cpp 0755 llama-cpp llama-cpp -"
    ];

    services.llama-swap = {
      enable = true;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      settings = {
        healthCheckTimeout = 60;
        logToStdout = "both";
        globalTTL = 0;
        sendLoadingState = true;
        models = {
          "Qwen3.6-27B Q3" = {
            name = "Qwen3.6-27B Q3";
            cmd =
              "${pkgs.llama-cpp-rocm}/bin/llama-server --host 0.0.0.0 --port "
              + "$"
              + "{PORT} --models-preset ${
                (pkgs.formats.ini { }).generate "big.ini" {
                  "Qwen3.6-27B Q3" = {
                    "hf-repo" = "unsloth/Qwen3.6-27B-GGUF";
                    "hf-file" = "Qwen3.6-27B-Q3_K_M.gguf";
                    ngl = "all";
                    fa = "on";
                    "cache-type-k" = "q4_0";
                    "cache-type-v" = "q4_0";
                    "fit-target" = 9500;
                    "ctx-size" = 32768;
                    "ubatch-size" = 1024;
                    "batch-size" = 2048;
                    "cache-reuse" = 256;
                    parallel = 2;
                  };
                }
              }";
            checkEndpoint = "/health";
            ttl = 0;
          };

        };
        groups = {
          default = {
            swap = false;
            members = [
              "Qwen3.6-27B Q3"
            ];
          };
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

    home-manager.users.${vars.username} = {
      home.packages = [ pkgs.docker-compose ];

      programs.opencode = {
        enable = true;
        context = ''
          ## Communication

          - You are a concise assistant. Keep answers short and avoid unnecessary preamble.
          - Never generate or guess URLs unless confident they are relevant.

          ## Environment

          - Assume nothing is installed locally. Always use `nix-shell -p <package> --run "<command>"` to invoke tools and commands.
          - Run lint/typecheck commands before completing work if they exist in the repo.
          - Do not commit changes unless explicitly asked.

          ## Code Style

          - Follow existing code conventions. Mimic style, naming, and patterns before introducing new ones.
          - Always write the simplest code possible.
          - Simplicity is trapping complex behavior within a simple interface — keep interfaces small.
          - Do not introduce new functions, classes, or symbols unless strictly required.

          ## API Design

          - Make illegal states unrepresentable — design errors out of existence.
          - Ask "how do I change the semantics so this is no longer an error?" not "how do I handle it?".
          - Prefer idempotent operations, total functions, and wide valid input over error handling.
          - Use types to eliminate invalid states at compile time (e.g., `NonEmptyList` vs `List`).
          - Absorb rare cases into the common case; eliminate special cases in data models.
          - Push complexity from the caller to the called — the library should be complex, the API should be simple.
          - Distinguish interface complexity from implementation complexity. Keep interfaces simple; implementation complexity is acceptable if it reduces interface complexity.
          - A small interface means "few things the caller is forced to think about."
          - Provide sensible defaults so parameters disappear for the common case.
          - Separate general-purpose core from special-purpose wrappers; don't let one-offs bloat the core interface.
          - Hide implementation details — callers should never need to know how something works to use it.
          - Favor few, deep methods over many, shallow ones.
          - Name things for what they mean, not how they're implemented.
          - Question every parameter: "does the caller need to know this at all?"

          ## Code Structure

          - Organize by business terms, not technical concerns — use vertical slices.
          - Never nest code beyond +1 level — a function can only have one level of nesting.
          - Never use `else`; prefer early returns.
          - Use immutability unless mutability is simpler.
          - Keep diffs as small as possible.
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
            models = {
              "Qwen3.6-27B Q3".name = "Qwen3.6-27B Q3";
            };
          };
        };
        agents = {
          architect = ''
            ---
            description: System architecture and design decisions
            mode: subagent
            model: llama/Qwen3.6-27B Q3
            temperature: 0.2
            permission:
              edit: deny
              bash:
                "*": deny
                "nix *": allow
                "git *": allow
            ---
            You are an architect agent. Analyze requirements, design system architecture, and make high-level technical decisions.

            Focus on:
            - System structure and module boundaries
            - API design and interface contracts
            - Tradeoffs between alternatives
            - Error handling strategy
            - Data flow and dependencies

            Provide concrete, actionable plans. Question assumptions and surface hidden complexity.
          '';
          coder = ''
            ---
            description: Implementation and code writing
            mode: subagent
            model: llama/Qwen3.6-27B Q3
            temperature: 0.1
            ---
            You are a coder agent. Implement features, fix bugs, and write clean code.

            Principles:
            - Write the simplest code that works
            - Never nest beyond one level — use early returns
            - Keep functions small and focused
            - Follow existing conventions
            - Question every parameter and dependency

            Run relevant tests or lint commands after making changes.
          '';
          researcher = ''
            ---
            description: Codebase exploration and research
            mode: subagent
            model: llama/Qwen3.6-27B Q3
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
            model: llama/Qwen3.6-27B Q3
            temperature: 0.1
            ---
            You are a tester agent. Write tests and verify code correctness.

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
