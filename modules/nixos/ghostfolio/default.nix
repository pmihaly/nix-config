{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.ghostfolio;

in {
  options.modules.ghostfolio = { enable = mkEnableOption "ghostfolio"; };
  config = mkIf cfg.enable (mkMerge [

    {
      systemd.tmpfiles.rules =
        (map (x: "d ${x} 0775 ${vars.username} wheel - -")
          [ "${vars.storage}/Services/ghostfolio" ]);
    }

    (mkService {
      subdomain = "ghostfolio";
      port = 3333;
      dashboard = {
        category = "Finances";
        name = "Ghostfolio";
        logo = ./ghostfolio.png;
      };
      extraConfig = {
        virtualisation.oci-containers = {
          containers = {

            ghostfolio-app = {
              image = "ghostfolio/ghostfolio:2.25.0";
              ports = [ "3333:3333" ];
              environmentFiles =
                [ config.age.secrets."ghostfolio/secret-env-vars".path ];
              environment = {
                TZ = vars.timeZone;
                NODE_ENV = "production";
                REDIS_HOST = "host.containers.internal";
              };
              dependsOn = [ "ghostfolio-postgres" ];
            };

            ghostfolio-postgres = {
              image = "postgres:15-alpine";
              ports = [ "3332:5432" ];
              environmentFiles =
                [ config.age.secrets."ghostfolio/secret-env-vars".path ];
              environment = {
                TZ = vars.timeZone;
                NODE_ENV = "production";
                REDIS_HOST = "host.containers.internal";
              };
            };

          };
        };

        services.redis.servers.ghostfolio = {
          enable = true;
          port = 3379;
          requirePassFile = config.age.secrets."ghostfolio/redis-pass".path;
        };
      };
    })
  ]);
}
