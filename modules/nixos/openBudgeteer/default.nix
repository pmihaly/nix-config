{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.openBudgeteer;

in {
  options.modules.openBudgeteer = { enable = mkEnableOption "openBudgeteer"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "openbudgeteer";
    port = 6100;
    dashboard = {
      category = "Finances";
      name = "openBudgeteer";
      logo = ./openBudgeteer.png;
    };
    extraConfig = let
      directories = [
        "${vars.serviceConfig}/openBudgeteer"
        "${vars.storage}/Services/openBudgeteer"
      ];
    in {

      systemd.tmpfiles.rules =
        map (x: "d ${x} 0775 ${vars.username} wheel - -") directories;

      virtualisation.oci-containers = {
        containers = {
          openBudgeteer = {
            image = "axelander/openbudgeteer:1.7";
            ports = [ "6100:80" ];
            volumes = [
              "${vars.storage}/Services/openBudgeteer:/srv"
              "${vars.serviceConfig}/openBudgeteer:/config"
            ];
            environment = {
              CONNECTION_PROVIDER = "SQLITE";
              CONNECTION_DATABASE = "/srv/openbudgeteer.db";
              APPSETTINGS_CULTURE = "hu-HU";
            };
          };
        };
      };

    };
  });
}
