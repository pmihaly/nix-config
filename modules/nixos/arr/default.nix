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
    "${vars.serviceConfig}/bazarr"
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
      subdomain = "bazarr";
      port = 6767;
      dashboard = {
        category = "Media";
        name = "Bazarr";
        logo = ./bazarr.png;
      };
      extraConfig.virtualisation.oci-containers = {
          containers.bazarr = {
              image = "lscr.io/linuxserver/bazarr:v1.4.3-ls266";
              ports = [
                "6767:6767"
              ];
              volumes = [
                "${vars.storage}/Media/TV:${vars.storage}/Media/TV"
                "${vars.storage}/Media/Movies:${vars.storage}/Media/Movies"
                "${vars.serviceConfig}/bazarr:/config"
              ];
              environment = {
                TZ = vars.timeZone;
              };
            };
          };
    })

# ---
# services:
#   bazarr:
#     image: lscr.io/linuxserver/bazarr:v1.4.3-ls266
#     container_name: bazarr
#     environment:
#       - PUID=1000
#       - PGID=1000
#       - TZ=Etc/UTC
#     volumes:
#       - /path/to/bazarr/config:/config
#       - /path/to/movies:/movies #optional
#       - /path/to/tv:/tv #optional
#     ports:
#       - 6767:6767
#     restart: unless-stopped

  ]);
}
