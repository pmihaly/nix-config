{ lib, config, ... }:

with lib;
let cfg = config.modules.homer;

in {
  options.modules.homer = { enable = mkEnableOption "homer"; };
  config = mkIf cfg.enable {
    services.nginx = {
      virtualHosts.localhost.locations."^~ /homer" = {
        proxyPass = "http://localhost:8080/";
      };
    };

    virtualisation.arion.projects.skylab.settings.services = {

      homer = {
        service.image = "b4bz/homer:v23.10.1";
        service.ports = [
          "8080:8080"
        ];
        service.environment = {
          INIT_ASSETS = "0";
          SUBFOLDER = "/homer";
        };
        service.volumes = [
          "${toString ./.}/assets:/www/assets"
        ];
      };

    };
  };
}
