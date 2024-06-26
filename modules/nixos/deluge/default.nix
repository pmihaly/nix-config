{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.deluge;
in
{
  options.modules.deluge = {
    enable = mkEnableOption "deluge";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "deluge";
    port = 8112;
    dashboard = {
      category = "Media";
      name = "Deluge";
      logo = ./deluge.png;
    };
    extraConfig = {

      environment.persistence.${vars.persistDir} = {
        directories = [ "/var/lib/deluge" ];
      };

      services.deluge = {
        enable = true;
        declarative = true;
        user = vars.username;
        group = "multimedia";
        openFirewall = true;
        config = {
          download_location = "${vars.storage}/Media/Downloads";
          share_ratio_limit = "5.0";
          listen_ports = [ 6881 ];
          enabled_plugins = [ "Label" ];
        };
        authFile = builtins.toFile "auth" ''
          localclient::10
        '';
        web = {
          enable = true;
          openFirewall = true;
          port = 8112;
        };
      };
    };
  });
}
