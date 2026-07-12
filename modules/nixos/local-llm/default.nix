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
  llamaSwapCfg = config.services.llama-swap;
  configFile = (pkgs.formats.yaml { }).generate "config.yaml" llamaSwapCfg.settings;
in
{
  options.modules.local-llm = {
    enable = mkEnableOption "local-llm";
  };
  config = mkIf cfg.enable (mkMerge [
    (mkService {
      subdomain = "open-webui";
      port = 3000;
      dashboard = {
        category = "AI";
        name = "Open WebUI";
        logo = ./openwebui.svg;
      };
      extraConfig = {
        users.users.open-webui = {
          isSystemUser = true;
          group = "open-webui";
        };
        users.groups.open-webui = { };

        environment.persistence.${vars.persistDir}.directories = [ "/var/lib/open-webui" ];

        systemd.tmpfiles.rules = [ "d /var/lib/open-webui 0755 open-webui open-webui -" ];

        services.open-webui = {
          enable = true;
          host = "0.0.0.0";
          port = 3000;
          stateDir = "/var/lib/open-webui";
          environment = {
            OPENAI_API_BASE_URL = "http://127.0.0.1:8081/v1";
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
          DynamicUser = mkForce false;
          User = "open-webui";
          Group = "open-webui";
        };
      };
    })

    (mkService {
      subdomain = "llama-swap";
      port = 8081;
      dashboard = {
        category = "AI";
        name = "Llama Swap";
        logo = ./llama-swap.svg;
      };
      extraConfig = {
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
          port = 8081;
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
          DynamicUser = mkForce false;
          PrivateDevices = mkForce false;
          ProtectSystem = mkForce "false";
          User = "llama-cpp";
          Group = "llama-cpp";
          Environment = [ "LLAMA_CACHE=/var/cache/llama-cpp" ];
          ExecStart = mkForce "${pkgs.llama-swap}/bin/llama-swap --listen :${toString llamaSwapCfg.port} --config ${configFile}";
        };
      };
    })

    (mkService {
      subdomain = "searx";
      port = 8888;
      dashboard = {
        category = "AI";
        name = "SearXNG";
        logo = ./searx.svg;
      };
      extraConfig = {
        services.searx = {
          enable = true;
          settings = {
            server = {
              bind_address = "0.0.0.0";
              port = 8888;
              secret_key = "searxng-secret-${vars.username}";
            };
            search.formats = [
              "html"
              "json"
            ];
          };
        };
      };
    })
  ]);
}
