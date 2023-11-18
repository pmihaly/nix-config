{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.homer;

in {
  options.modules.homer = {
    enable = mkEnableOption "homer";
    homerConfig = mkOption {
      default = {
        title = "❄️🧙";
        logo = "assets/logo.png";
      };
      type = types.attrs;
    };
    services = mkOption {
      default = { };
      type = types.attrs;
    };
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "homer";
    port = 8080;
    extraConfig = {
      virtualisation.oci-containers.containers = {
        homer = let

          logoVolumes = trivial.pipe cfg.services [
            builtins.attrValues
            (map builtins.attrValues)
            lists.flatten
            (map (service: service.logo))
            (map (logo: "${logo}:/www/assets${logo}"))
          ];

          mappedServices = lib.mapAttrsToList (groupName: groupData: {
            name = groupName;
            items = lib.mapAttrsToList (serviceName: serviceData: {
              name = serviceName;
              logo = "assets/${serviceData.logo}";
              url = serviceData.url;
              target = "_blank";
            }) groupData;
          }) cfg.services;

          homerConfig = { services = mappedServices; } // cfg.homerConfig;
        in {
          image = "b4bz/homer:v23.10.1";
          ports = [ "8080:8080" ];
          volumes = [
            "${./assets}:/www/assets"
            "${
              (pkgs.formats.yaml { }).generate "config.yml" homerConfig
            }:/www/assets/config.yml"
          ] ++ logoVolumes;
          environment = { INIT_ASSETS = "0"; };
        };

      };
    };
  });
}
