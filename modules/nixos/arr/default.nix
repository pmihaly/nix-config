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

      nixpkgs.config.permittedInsecurePackages = trivial.warn "check https://github.com/NixOS/nixpkgs/issues/360592" [
        "aspnetcore-runtime-6.0.36"
        "aspnetcore-runtime-wrapped-6.0.36"
        "dotnet-sdk-6.0.428"
        "dotnet-sdk-wrapped-6.0.428"
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
  ]);
}
