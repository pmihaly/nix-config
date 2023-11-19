{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.monitoring;

in {
  options.modules.monitoring = { enable = mkEnableOption "monitoring"; };
  config = mkIf cfg.enable (mkMerge [

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
            ];
          }];
        }];
      };
    }

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
        };
        provision.datasources.settings = {
          apiVersion = 1;
          datasources = [{
            name = "Prometheus";
            url = "http://localhost:9001";
            type = "prometheus";
          }];
        };
      };
    })

  ]);
}
