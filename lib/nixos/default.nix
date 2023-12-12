{ lib, vars }:
let
  mkService = { subdomain, port, dashboard ? null, extraConfig
    , extraNginxConfigRoot ? { }, extraNginxConfigLocation ? { }
    , bypassAuth ? false }:
    lib.mkMerge [
      {
        services.nginx = {
          virtualHosts."${subdomain}.${vars.domainName}" = {
            forceSSL = true;
            enableACME = true;
            locations."/" = {
              proxyPass = "http://localhost:${toString port}";
            } // extraNginxConfigLocation;
          } // extraNginxConfigRoot;
        };
      }

      {
        modules.homer.services = lib.mkIf (builtins.isAttrs dashboard) {
          "${dashboard.category}"."${dashboard.name}" = {
            logo = dashboard.logo;
            url = "https://${subdomain}.${vars.domainName}";
          };
        };
      }

      {
        modules.authelia.bypassDomains =
          lib.mkIf bypassAuth [ "${subdomain}.${vars.domainName}" ];
      }

      extraConfig
    ];

in { inherit mkService; }
