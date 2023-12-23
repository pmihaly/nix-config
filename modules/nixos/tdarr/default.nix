{ lib, config, vars, ... }:

with lib;
let
  cfg = config.modules.tdarr;
  directories = [
    "${vars.serviceConfig}/tdarr/server"
    "${vars.serviceConfig}/tdarr/configs"
    "${vars.storage}/Services/tdarr/logs"
    "${vars.storage}/Media/Movies"
    "${vars.storage}/Media/TV"
    "${vars.storage}/Services/tdarr/cache"
  ];

in {
  options.modules.tdarr = { enable = mkEnableOption "tdarr"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "tdarr";
    port = 8265;
    dashboard = {
      category = "Media";
      name = "tdarr";
      logo = ./tdarr.png;
    };
    extraConfig = mkMerge [
      { networking.firewall.allowedTCPPorts = [ 8266 ]; }
      {
        systemd.tmpfiles.rules =
          map (x: "d ${x} 0775 ${vars.username} multimedia - -") directories;
      }

      {
        virtualisation.oci-containers.containers.tdarr = {
          image = "ghcr.io/haveagitgat/tdarr:2.17.01";
          ports = [ "8265:8265" "8266:8266" ];
          volumes = [
            "${vars.serviceConfig}/tdarr/server:/app/server"
            "${vars.serviceConfig}/tdarr/configs:/app/configs"
            "${vars.storage}/Services/tdarr/logs:/app/logs"
            "${vars.storage}/Media/Movies:/media/Movies"
            "${vars.storage}/Media/TV:/media/TV"
            "${vars.storage}/Services/tdarr/cache:/temp"
          ];
          extraOptions = [ "--device=/dev/dri/renderD128:/dev/dri/renderD128" ];
          environment = {
            TZ = vars.timeZone;
            serverIP = "0.0.0.0";
            serverPort = "8266";
            webUIPort = "8265";
            internalNode = "true";
            inContainer = "true";
            ffmpegVersion = "6";
            nodeName = "my-internal-node";
          };
        };
      }
    ];
  });
}
