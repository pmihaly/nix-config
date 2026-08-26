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

  # One homer instance: a b4bz/homer container plus its mkService wiring
  # (tailnet-only port, tailnet vhost redirect, optional public vhost /
  # apex). Used for both the private (tailnet) instance and the optional
  # public one; only the board content, port and exposure differ.
  mkInstance =
    {
      # Container name + tailnet vhost path (/homer, /homer-public, ...)
      name,
      port,
      services,
      title,
      homerConfig,
      # Serve the app under /<subfolder> (set), or at / (null — the image
      # default, for an instance proxied by nginx on the apex domain).
      subfolder ? null,
      public ? false,
      apex ? false,
    }:
    let
      logoVolumes =
        services
        |> builtins.attrValues
        |> (map builtins.attrValues)
        |> lists.flatten
        |> (map (service: service.logo))
        |> (map (logo: "${logo}:/www/assets${logo}"));

      mappedServices = lib.mapAttrsToList (groupName: groupData: {
        name = groupName;
        items = lib.mapAttrsToList (serviceName: serviceData: {
          name = serviceName;
          logo = "assets/${serviceData.logo}";
          url = serviceData.url;
          target = "_blank";
        }) groupData;
      }) services;

      instanceConfig = {
        documentTitle = title;
        title = title;
        services = mappedServices;
        footer = false;
      }
      // homerConfig;

      container = {
        image = "docker.io/b4bz/homer:${getDockerVersionFromShield inputs.homer-shield}";
        ports = [ "${toString port}:8080" ];
        volumes = [
          "${(pkgs.formats.yaml { }).generate "config.yml" instanceConfig}:/www/assets/config.yml"
        ]
        ++ logoVolumes;
        # SUBFOLDER omitted entirely when serving at / — the image default.
        environment = {
          INIT_ASSETS = "0";
        }
        // (optionalAttrs (subfolder != null) { SUBFOLDER = subfolder; });
      };
    in
    mkService {
      subdomain = name;
      port = port;
      inherit public apex;
      extraConfig = {
        virtualisation.oci-containers.containers.${name} = container;
      };
    };
in
{
  options.modules.homer = {
    enable = mkEnableOption "homer (the private, tailnet-only instance)";

    homerConfig = mkOption {
      default = { };
      type = types.attrs;
    };

    services = mkOption {
      default = null;
      type = types.nullOr types.anything;
    };

    # Optional second instance, served publicly on the apex domain
    # (default_server vhost + Let's Encrypt, via mkService) for machines
    # that expose a dashboard to the internet (skylake). The tailnet keeps
    # getting the private instance at /homer.
    public = {
      enable = mkEnableOption "public homer instance (served on the apex domain)";
      port = mkOption {
        default = 8081;
        type = types.port;
      };
      subdomain = mkOption {
        default = "homer-public";
        type = types.str;
      };
      # Board content for the public instance only — same shape as
      # `services` above (groups of { logo, url } entries), but NOT the
      # private board (that one is fed by every service's mkService
      # `dashboard` self-registration).
      services = mkOption {
        default = { };
        type = types.attrs;
      };
      homerConfig = mkOption {
        default = { };
        type = types.attrs;
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable (mkInstance {
      name = "homer";
      port = 8080;
      subfolder = "/homer";
      title = "❄️🧙";
      inherit (cfg) services homerConfig;
    }))

    (mkIf cfg.public.enable (mkInstance {
      name = cfg.public.subdomain;
      port = cfg.public.port;
      subfolder = null;
      title = "❄️🧙";
      public = true;
      apex = true;
      inherit (cfg.public) services homerConfig;
    }))
  ];
}
