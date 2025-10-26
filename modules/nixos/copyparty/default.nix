{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.copyparty;
in
{
  options.modules.copyparty = {
    enable = mkEnableOption "copyparty";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "copyparty";
    port = 3210;
    dashboard = {
      category = "Documents";
      name = "Copyparty";
      logo = ./copyparty.svg;
    };
    extraConfig.services.copyparty = {
      enable = true;
      user = "root";
      group = "root";
      settings = {
        i = "0.0.0.0";
        p = [
          3210
        ];
        no-reload = true;
        ignored-flag = false;
      };

      volumes = {
        "/" = {
          path = "/";
          access = {
            A = "*";
          };
          flags = {
            fk = 4;
            scan = 60;
            nohash = "\.iso$";
            e2d = true;
            d2t = true;
            hist = "${vars.storage}/Services/copyparty";
          };
        };
      };
    };
  });
}
