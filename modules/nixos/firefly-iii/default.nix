{ lib, config, vars, inputs, ... }:

with lib;
let cfg = config.modules.firefly-iii;

in {
  options.modules.firefly-iii = { enable = mkEnableOption "firefly-iii"; };
  config = mkIf cfg.enable (mkMerge [

    (mkService {
      subdomain = "firefly-iii";
      port = 8083;
      dashboard = {
        category = "Finances";
        name = "Firefly III";
        logo = ./firefly-iii.png;
      };
      extraConfig = let
        directories = [
          "${vars.storage}/Services/firefly-iii"
          "${vars.storage}/Services/firefly-iii/upload"
        ];
        files = [ "${vars.storage}/Services/firefly-iii/database.sqlite" ];
      in {

        systemd.tmpfiles.rules =
          (map (x: "d ${x} 0775 ${vars.username} wheel - -") directories)
          ++ (map (x: "f ${x} 0775 ${vars.username} wheel - -") files);

        virtualisation.oci-containers = {
          containers = {
            firefly-iii-app = {
              image = "fireflyiii/core:version-6.0.30";
              ports = [ "8083:8080" ];
              volumes = [
                "${vars.storage}/Services/firefly-iii/database.sqlite:/storage/database/database.sqlite"
                "${vars.storage}/Services/firefly-iii/upload:/var/www/html/storage/upload"
              ];
              environmentFiles = [ inputs.firefly-env ];
              environment = {
                TZ = vars.timeZone;
                DB_CONNECTION = "sqlite";
                DB_HOST = "";
                DB_PORT = "";
                DB_DATABASE = "";
                DB_USERNAME = "";
                DB_PASSWORD = "";
                ENABLE_EXTERNAL_RATES = "true";
                VALID_URL_PROTOCOLS = "https";
              } // (mkIf config.modules.authelia.enable {
                AUTHENTICATION_GUARD = "remote_user_guard";
                AUTHENTICATION_GUARD_HEADER = "Remote-User";
                AUTHENTICATION_GUARD_EMAIL = "Remote-Email";
              });
            };

            # TODO cron
          };
        };

      };
    })

    (mkService {
      subdomain = "firefly-iii-importer";
      port = 8084;
      dashboard = {
        category = "Finances";
        name = "Firefly III Importer";
        logo = ./firefly-iii.png;
      };
      extraConfig.virtualisation.oci-containers.containers.firefly-iii-importer =
        {
          image = "fireflyiii/data-importer:version-1.3.9";
          ports = [ "8084:8080" ];
          environmentFiles = [ inputs.firefly-env ];
          environment = {
            TZ = vars.timeZone;
            FIREFLY_III_URL = "http://host.containers.internal:8083";
            VANITY_URL = "https://firefly-iii.${vars.domainName}";
          };
        };
    })

  ]);
}
