{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.monitoring;

in {
  options.modules.monitoring = { enable = mkEnableOption "monitoring"; };
  config = mkIf cfg.enable (mkMerge [

    (mkService {
      subdomain = "grafana";
      port = 2342;
      dashboard = {
        category = "Admin";
        name = "Grafana";
        logo = ./grafana.png;
      };
      extraNginxConfigLocation.proxyWebsockets = true;
      extraConfig.services.grafana = {
        enable = true;
        settings = {
          server = {
            domain = "grafana.${vars.domainName}";
            http_port = 2342;
            enable_gzip = true;
            enforce_domain = true;
          };
          users = { allow_sign_up = false; };
          analytics.reporting_enabled = false;
        };
        provision.datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              url =
                "http://localhost:${toString config.services.prometheus.port}";
              type = "prometheus";
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:${
                  toString
                  config.services.loki.configuration.server.http_listen_port
                }";
            }
          ];
        };
      };
    })

    {
      services.prometheus = {
        enable = true;
        port = 9001;
        exporters = {
          node = {
            enable = true;
            enabledCollectors = [ "systemd" ];
            port = 9002;
          };
        };
        scrapeConfigs = [{
          job_name = "skylake";
          static_configs = [{
            targets = [
              "127.0.0.1:${
                toString config.services.prometheus.exporters.node.port
              }"
              "127.0.0.1:${
                toString config.services.endlessh-go.prometheus.port
              }"
            ];
          }];
        }];
      };
    }

    {
      services.loki = {
        enable = true;
        configuration = {
          server.http_listen_port = 3100;
          auth_enabled = false;

          ingester = {
            lifecycler = {
              address = "127.0.0.1";
              ring = {
                kvstore = { store = "inmemory"; };
                replication_factor = 1;
              };
            };
            chunk_idle_period = "1h";
            max_chunk_age = "1h";
            chunk_target_size = 999999;
            chunk_retain_period = "30s";
            max_transfer_retries = 0;
          };

          schema_config = {
            configs = [{
              from = "2022-06-06";
              store = "boltdb-shipper";
              object_store = "filesystem";
              schema = "v11";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }];
          };

          storage_config = {
            boltdb_shipper = {
              active_index_directory = "/var/lib/loki/boltdb-shipper-active";
              cache_location = "/var/lib/loki/boltdb-shipper-cache";
              cache_ttl = "24h";
              shared_store = "filesystem";
            };

            filesystem = { directory = "/var/lib/loki/chunks"; };
          };

          limits_config = {
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
          };

          chunk_store_config = { max_look_back_period = "0s"; };

          table_manager = {
            retention_deletes_enabled = false;
            retention_period = "0s";
          };

          compactor = {
            working_directory = "/var/lib/loki";
            shared_store = "filesystem";
            compactor_ring = { kvstore = { store = "inmemory"; }; };
          };
        };
      };
    }

    {
      services.promtail = {
        enable = true;
        configuration = {
          server = { http_listen_port = 3031; grpc_listen_port = 3032; };
          positions = { filename = "/tmp/positions.yaml"; };
          clients = [{
            url = "http://127.0.0.1:${
                toString
                config.services.loki.configuration.server.http_listen_port
              }/loki/api/v1/push";
          }];
          scrape_configs = [{
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "pihole";
              };
            };
            relabel_configs = [{
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }];
          }];
        };
      };
    }

  ]);
}
