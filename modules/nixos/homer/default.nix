{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.homer;
in
{
  options.modules.homer = {
    enable = mkEnableOption "homer";
    homerConfig = mkOption {
      default = { };
      type = types.attrs;
    };
    services = mkOption {
      default = null;
      type = types.nullOr types.anything;
    };
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "homer";
    port = 8080;
    extraConfig = {
      virtualisation.oci-containers.containers = {
        homer =
          let

            logoVolumes =
              cfg.services
              |> builtins.attrValues
              |> (map builtins.attrValues)
              |> lists.flatten
              |> (map (service: service.logo))
              |> (map (logo: "${logo}:/www/assets${logo}"));

            mappedServices = lib.mapAttrsToList (groupName: groupData: {
              name = groupName;
              items = lib.mapAttrsToList (serviceName: serviceData: {
                name = serviceName;
                logo = "assets/${serviceData.logo}";
                url = serviceData.url;
                target = "_blank";
              }) groupData;
            }) cfg.services;

            homerConfig = {
              documentTitle = "❄️🧙";
              title = "❄️🧙";
              services = mappedServices;
              footer = false;
            } // cfg.homerConfig;

          in
          {
            image = "b4bz/homer:${getDockerVersionFromShield inputs.homer-shield}";
            ports = [ "8080:8080" ];
            volumes = [
              "${(pkgs.formats.yaml { }).generate "config.yml" homerConfig}:/www/assets/config.yml"
            ] ++ logoVolumes;
            environment = {
              INIT_ASSETS = "0";
              SUBFOLDER = "/homer";
            };
          };
      };
    };
  });
}
