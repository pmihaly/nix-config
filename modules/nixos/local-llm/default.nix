{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.local-llm;
in
{
  options.modules.local-llm = {
    enable = mkEnableOption "local-llm";
  };
  config = mkIf cfg.enable {
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
          "SEARXNG_SETTINGS_PATH=${
            pkgs.writeTextFile {
              name = "searxng-settings.yml";
              text = ''
                use_default_settings: true
                server:
                  bind_address: "127.0.0.1"
                  secret_key: "searxng-secret-${vars.username}"
                search:
                  formats:
                    - html
                    - json
              '';
            }
          }"
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
        OPENAI_API_BASE_URL = "http://127.0.0.1:8080/v1";
        OPENAI_API_KEY = "local";
        ENABLE_OLLAMA_API = "false";
        WEBUI_URL = "";
        SEARXNG_QUERY_URL = "http://127.0.0.1:8888";
        ENABLE_WEB_SEARCH = "true";
        WEB_SEARCH_ENGINE = "searxng";
        BYPASS_RETRIEVAL_ACCESS_CONTROL = "true";
      };
    };

    systemd.services.open-webui.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "open-webui";
      Group = "open-webui";
    };
  };
}
