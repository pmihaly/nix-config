{ lib, config, vars, ... }:

with lib;
let
  cfg = config.modules.arr;
  directories = [
    "${vars.serviceConfig}/sonarr"
    "${vars.serviceConfig}/radarr"
    "${vars.serviceConfig}/prowlarr"
    "${vars.storage}/Media/Downloads"
    "${vars.storage}/Media/TV"
    "${vars.storage}/Media/Movies"
    "${vars.storage}/Media/Audiobooks"
  ];

in {
  options.modules.arr = { enable = mkEnableOption "arr"; };
  config = mkIf cfg.enable (mkMerge [
    {
      systemd.tmpfiles.rules =
        map (x: "d ${x} 0775 ${vars.username} wheel - -") directories;
    }

    (mkService {
      subdomain = "sonarr";
      port = 8989;
      dashboard = {
        category = "Media";
        name = "Sonarr";
        logo = ./sonarr.svg;
      };
      extraConfig = {
        virtualisation.oci-containers.containers = {
          sonarr = {
            image = "lscr.io/linuxserver/sonarr:develop-4.0.0.725-ls8";
            ports = [ "8989:8989" ];
            volumes = [
              "${vars.storage}/Media/Downloads:/downloads"
              "${vars.storage}/Media/TV:/tv"
              "${vars.serviceConfig}/sonarr:/config"
            ];
            environment = { TZ = vars.timeZone; };
          };
        };
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
      extraConfig = {
        services.prowlarr = {
          enable = true;
          openFirewall = true;
        };
      };
    })
  ]);
}
