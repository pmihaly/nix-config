{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.deluge;

in {
  options.modules.deluge = { enable = mkEnableOption "deluge"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "deluge";
    port = 8112;
    dashboard = {
      category = "Media";
      name = "Deluge";
      logo = ./deluge.png;
    };
    extraConfig = {

      services.deluge = {
        enable = true;
        declarative = true;
        user = vars.username;
        group = "wheel";
        openFirewall = true;
        config = {
          download_location = "${vars.storage}/Media/Downloads";
          share_ratio_limit = "2.0";
          listen_ports = [ 6881 ];
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
