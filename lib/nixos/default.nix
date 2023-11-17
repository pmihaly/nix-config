{ lib }:
let

  mkService = { subdomain, port, dashboard ? null, extraConfig }:
    lib.mkMerge [
      {
        services.nginx = {
          virtualHosts."${subdomain}.skylake.mihaly.codes" = {
            forceSSL = true;
            enableACME = true;

            locations."/" = {
              proxyPass = "http://localhost:${toString port}";
            };
          };
        };
      }

      {
        modules.homer.services = lib.mkIf (builtins.isAttrs dashboard) {
          "${dashboard.category}"."${dashboard.name}" = {
            logo = dashboard.logo;
            url = "https://${subdomain}.skylake.mihaly.codes";
          };
        };
      }

      extraConfig
    ];

in { inherit mkService; }
