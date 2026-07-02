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

    systemd.services.llama-cpp = {
      description = "llama.cpp HTTP server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "llama-cpp";
        Group = "llama-cpp";

        WorkingDirectory = "/var/lib/llama-cpp";

        StateDirectory = "";
        CacheDirectory = "";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = false;

        ProtectSystem = "strict";
        ProtectHome = true;

        ReadWritePaths = [
          "/var/lib/llama-cpp"
          "/var/cache/llama-cpp"
        ];

        Restart = "on-failure";
        RestartSec = 5;
      };

      environment = {
        LLAMA_CACHE = "/var/cache/llama-cpp";
      };

      script = ''
        exec ${pkgs.llama-cpp-rocm}/bin/llama-server \
          --host 0.0.0.0 \
          --port 8083 \
          --models-preset ${
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
          }
      '';
    };
    users.users.llama-cpp = {
      isSystemUser = true;
      group = "llama-cpp";
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

    home-manager.users.${vars.username} = {
      home.packages = [ pkgs.docker-compose ];

      programs.opencode = {
        enable = true;
        context = ''
          You are a concise assistant. Keep answers short and avoid unnecessary preamble.
          Assume nothing is installed locally. Always use `nix-shell -p <package> --run "<command>"` to invoke tools and commands.
          Never generate or guess URLs unless confident they are relevant.
          Follow existing code conventions. Mimic style, naming, and patterns before introducing new ones.
          Run lint/typecheck commands before completing work if they exist in the repo.
          Do not commit changes unless explicitly asked.
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
            baseURL = "http://127.0.0.1:8083/v1";
            apiKey = "local";
          };
          models."Qwen3.6-27B Q4 +MTP".name = "Qwen3.6-27B Q4 +MTP";
        };
        };
      };

      modules.persistence.directories = [
        ".config/aws"
        ".local/share/docker"
        ".config/opencode"
      ];
    };
  };
}
