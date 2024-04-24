{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.arr;
  directories = [
    "${vars.serviceConfig}/sonarr"
    "${vars.serviceConfig}/radarr"
    "${vars.serviceConfig}/prowlarr"
    "${vars.serviceConfig}/jellyseerr"
    "${vars.storage}/Media/Downloads"
    "${vars.storage}/Media/TV"
    "${vars.storage}/Media/Movies"
    "${vars.storage}/Media/Audiobooks"
  ];
in
{
  options.modules.arr = {
    enable = mkEnableOption "arr";
  };
  config = mkIf cfg.enable (mkMerge [
    {
      systemd.tmpfiles.rules = map (x: "d ${x} 0775 ${vars.username} multimedia - -") directories;

      environment.persistence.${vars.persistDir}.directories = [
        {
          directory = "/var/lib/private/prowlarr";
          mode = "0700";
        }
        "/var/lib/sonarr/.config/NzbDrone"
        "/var/lib/radarr/.config/Radarr"
      ];
    }

    (mkService {
      subdomain = "sonarr";
      port = 8989;
      dashboard = {
        category = "Media";
        name = "Sonarr";
        logo = ./sonarr.svg;
      };
      extraConfig.services.sonarr = {
        enable = true;
        group = "multimedia";
      };
    })

    (mkService {
      subdomain = "radarr";
      port = 7878;
      dashboard = {
        category = "Media";
        name = "Radarr";
        logo = ./radarr.png;
      };
      extraConfig.services.radarr = {
        enable = true;
        group = "multimedia";
      };
    })

    (mkService {
      subdomain = "prowlarr";
      port = 9696;
      dashboard = {
        category = "Media";
        name = "Prowlarr";
        logo = ./prowlarr.png;
      };
      extraConfig.services.prowlarr.enable = true;
    })

    (mkService {
      subdomain = "jellyseerr";
      port = 5055;
      dashboard = {
        category = "Media";
        name = "Jellyseerr";
        logo = ./jellyseerr.png;
      };
      bypassAuth = true;
      extraConfig.virtualisation.oci-containers.containers.jellyseerr = {
        image = "fallenbagel/jellyseerr:1.7.0";
        ports = [ "5055:5055" ];
        environment = {
          LOG_LEVEL = "debug";
          TZ = vars.timeZone;
        };
        volumes = [ "${vars.serviceConfig}/jellyseerr:/app/config" ];
      };
    })
  ]);
}
