{ lib, config, ... }:

with lib;
let cfg = config.modules.homer;

in {
  options.modules.homer = { enable = mkEnableOption "homer"; };
  config = mkIf cfg.enable {
    virtualisation.arion.projects.skylab.settings.services = {

      homer = {
        service.image = "b4bz/homer:v23.10.1";
        service.ports = [
          "8080:8080"
        ];
        service.environment = {
          INIT_ASSETS = "0";
        };
        service.volumes = [
          "${toString ./.}/assets:/www/assets"
        ];
      };

      nginx.nixos.configuration.services.nginx = {
        virtualHosts.localhost.locations."/homer" = {
          proxyPass = "http://127.0.0.1:8080";
        };
      };

    };
  };
}
