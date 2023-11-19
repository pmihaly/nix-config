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
        };
      };
    })

  ]);
}
