{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.jellyfin;

in {
  options.modules.jellyfin = { enable = mkEnableOption "jellyfin"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "jellyfin";
    port = 8096;
    dashboard = {
      category = "Media";
      name = "Jellyfin";
      logo = ./jellyfin.png;
    };
    bypassAuth = true;
    extraConfig = let
      directories = [
        "${vars.serviceConfig}/jellyfin"
        "${vars.storage}/Media/TV"
        "${vars.storage}/Media/Movies"
      ];
    in {
      systemd.tmpfiles.rules =
        map (x: "d ${x} 0775 ${vars.username} multimedia - -") directories;

      services.nginx.virtualHosts."jellyfin.${vars.domainName}".locations = {
        "/socket" = {
          extraConfig = ''
            proxy_pass http://localhost:8096;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
          '';
        };
      };

      networking.firewall = { allowedUDPPorts = [ 1900 7359 ]; };

      virtualisation.oci-containers = {
        containers = {
          jellyfin = {
            image = "lscr.io/linuxserver/jellyfin:10.8.12";
            ports = [ "8096:8096" "1900:1900/udp" "7359:7359/udp" ];
            volumes = [
              "${vars.storage}/Media/TV:/data/tvshows"
              "${vars.storage}/Media/Movies:/data/movies"
              "${vars.serviceConfig}/jellyfin:/config"
            ];
            environment = {
              TZ = vars.timeZone;
              JELLYFIN_PublishedServerUrl = "jellyfin.${vars.domainName}";
            };
            extraOptions = [
              "--device=/dev/dri/renderD128:/dev/dri/renderD128"
            ];
          };
        };
      };
    };
  });
}
