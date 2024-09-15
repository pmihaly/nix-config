{
  lib,
  inputs,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.jellyfin;
in
{
  options.modules.jellyfin = {
    enable = mkEnableOption "jellyfin";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "jellyfin";
    port = 8096;
    dashboard = {
      category = "Media";
      name = "Jellyfin";
      logo = ./jellyfin.png;
    };
    bypassAuth = true;
    extraConfig =
      let
        directories = [
          "${vars.serviceConfig}/jellyfin"
          "${vars.storage}/Media/TV"
          "${vars.storage}/Media/Movies"
        ];
      in
      {
        systemd.tmpfiles.rules = map (x: "d ${x} 0775 ${vars.username} multimedia - -") directories;

        networking.firewall = {
          allowedUDPPorts = [ 7359 ];
        };

        virtualisation.oci-containers = {
          containers = {
            jellyfin = {
              image = "lscr.io/linuxserver/jellyfin:${
                builtins.replaceStrings [ "v" ] [ "" ] (getDockerVersionFromShield inputs.jellyfin-shield)
              }";
              ports = [
                "8096:8096"
                "7359:7359/udp"
              ];
              volumes = [
                "${vars.storage}/Media/TV:/data/tvshows"
                "${vars.storage}/Media/Movies:/data/movies"
                "${vars.serviceConfig}/jellyfin:/config"
              ];
              environment = {
                TZ = vars.timeZone;
                JELLYFIN_PublishedServerUrl = "${vars.domainName}/jellyfin";
              };
              extraOptions = [ "--device=/dev/dri/renderD128:/dev/dri/renderD128" ];
            };
          };
        };
      };
  });
}
