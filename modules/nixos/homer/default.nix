{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.homer;

in {
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
        homer = let

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
            subtitle = "skylake";
            logo = "assets/dark_circle.png";
            stylesheet = [ "assets/catppuccin-mocha.css" ];
            services = mappedServices;
            footer = false;
          } // cfg.homerConfig;

          style = builtins.fetchurl {
            url =
              "https://raw.githubusercontent.com/mrpbennett/catppuccin-homer/main/flavours/catppuccin-mocha.css";
            sha256 = "1jkj55fqv1wyx71idfbwyfjy66r4hmfxlk1lpxqxhnjwizi037xq";
          };
          background = builtins.fetchurl {
            url =
              "https://raw.githubusercontent.com/mrpbennett/catppuccin-homer/main/assets/images/backgrounds/romb.png";
            sha256 = "14yaxr50db4h93cc1i9qhr5g2r33dds64p2yl7pz4w01xxp2qmh7";
          };
          logo = builtins.fetchurl {
            url =
              "https://raw.githubusercontent.com/mrpbennett/catppuccin-homer/main/assets/logos/dark_circle.png";
            sha256 = "1amnsl2vs5hc0jklmpn69lyvrnkckz8v9c9r70hdjjkns82p1kh3";
          };
          favicons = pkgs.fetchzip {
            url =
              "https://raw.githubusercontent.com/mrpbennett/catppuccin-homer/main/assets/favicons/dark_favicon.zip";
            hash = "sha256-xp9A4sesO1O0u5vwnFSQrhN+PTqo/v0iiHvarwdoPi8";
            stripRoot = false;
          };

        in {
          image = "b4bz/homer:v23.10.1";
          ports = [ "8080:8080" ];
          volumes = [
            "${style}:/www/assets/catppuccin-mocha.css"
            "${background}:/www/assets/images/romb.png"
            "${logo}:/www/assets/dark_circle.png"
            "${favicons}:/www/assets/icons"
            "${
              (pkgs.formats.yaml { }).generate "config.yml" homerConfig
            }:/www/assets/config.yml"
          ] ++ logoVolumes;
          environment = { INIT_ASSETS = "0"; };
        };

      };
    };
  });
}
