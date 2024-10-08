{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.homer;
in
{
  options.modules.homer = {
    enable = mkEnableOption "homer";
    homerConfig = mkOption {
      default = { };
      type = types.attrs;
    };
    services = mkOption {
      default = null;
      type = types.nullOr types.anything;
    };
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "homer";
    port = 8080;
    extraConfig = {
      virtualisation.oci-containers.containers = {
        homer =
          let

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

            homerConfig = {
              documentTitle = "❄️🧙";
              title = "❄️🧙";
              subtitle = "skylake build ${inputs.self.lastModifiedDate}";
              logo = "assets/dark_circle.png";
              stylesheet = [ "assets/catppuccin-frappe.css" ];
              services = mappedServices;
              footer = false;
            } // cfg.homerConfig;

            catpuccin-homer = (
              pkgs.fetchFromGitHub {
                owner = "mrpbennett";
                repo = "catppuccin-homer";
                rev = "377dd768acd4e87560db75edc312ddd7b62b3252";
                hash = "sha256-WvmwnMQOglXtJJPXI/CWuEDTgUylZV9nuILodTPRAY4=";
              }
            );

            style = catpuccin-homer + /flavours/catppuccin-frappe.css;
            background = catpuccin-homer + /assets/images/backgrounds/romb.png;
            logo = catpuccin-homer + /assets/logos/dark_circle.png;
            favicons = pkgs.stdenv.mkDerivation {
              name = "favicons";
              src = catpuccin-homer;
              phases = [ "unpackPhase" ];
              nativeBuildInputs = [ pkgs.unzip ];
              unpackPhase = "unzip -o $src/assets/favicons/dark_favicon.zip -d $out";
            };
          in
          {
            image = "b4bz/homer:${getDockerVersionFromShield inputs.homer-shield}";
            ports = [ "8080:8080" ];
            volumes = [
              "${style}:/www/assets/catppuccin-frappe.css"
              "${background}:/www/assets/images/romb.png"
              "${logo}:/www/assets/dark_circle.png"
              "${favicons}:/www/assets/icons"
              "${(pkgs.formats.yaml { }).generate "config.yml" homerConfig}:/www/assets/config.yml"
            ] ++ logoVolumes;
            environment = {
              INIT_ASSETS = "0";
              SUBFOLDER = "/homer";
            };
          };
      };
    };
  });
}
