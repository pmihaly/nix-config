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
          return = "301 http://${vars.domainName}:${toString port}";
        };

        modules.homer.services = lib.mkIf (builtins.isAttrs dashboard) {
          "${dashboard.category}"."${dashboard.name}" = {
            logo = dashboard.logo;
            url = "http://${vars.domainName}:${toString port}";
          };
        };
      }
      extraConfig
    ];
  getDockerVersionFromShield =
    githubTags:
    lib.trivial.pipe githubTags [
      builtins.readFile
      builtins.fromJSON
      (builtins.getAttr "value")
    ];
in
{
  inherit mkService getDockerVersionFromShield;
}
