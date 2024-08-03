{ lib, vars }:
let
  mkService =
    {
      subdomain,
      port,
      dashboard ? null,
      extraConfig,
      extraNginxConfigRoot ? { },
      extraNginxConfigLocation ? { },
      bypassAuth ? false,
    }:
    lib.mkMerge [
      {

        networking.firewall = {
          allowedTCPPorts = [ port ];
        };

        services.nginx.virtualHosts."${vars.domainName}".locations."/${subdomain}" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:${toString port}/$1";
        };

        modules.homer.services = lib.mkIf (builtins.isAttrs dashboard) {
          "${dashboard.category}"."${dashboard.name}" = {
            logo = dashboard.logo;
            url = "http://${vars.domainName}/${subdomain}";
          };
        };
      }
      extraConfig
    ];
in
{
  inherit mkService;
}
