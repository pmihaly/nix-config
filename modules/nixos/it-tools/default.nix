{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.it-tools;
in
{
  options.modules.it-tools = {
    enable = mkEnableOption "it-tools";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "it-tools";
    port = 8088;
    dashboard = {
      category = "Documents";
      name = "IT Tools";
      logo = "${pkgs.it-tools}/lib/android-chrome-512x512.png";
    };
    extraConfig.services.nginx.virtualHosts."it-tools" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8088;
        }
      ];
      locations."/".root = "${pkgs.it-tools}/lib/";
    };
  });
}
