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
    # Public: https://it-tools.skylake.mihaly.codes (nginx on 80/443 proxies
    # to this vhost's port 8088 on loopback; cert via Let's Encrypt).
    public = true;
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
