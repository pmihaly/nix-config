{
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.stirling-pdf;
in
{
  options.modules.stirling-pdf = {
    enable = mkEnableOption "stirling-pdf";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "stirling-pdf";
    port = 8081;
    dashboard = {
      category = "Documents";
      name = "Stirling-PDF";
      logo = ./stirling.png;
    };
    extraConfig.services.stirling-pdf = {
      enable = true;
      environment.SERVER_PORT = 8081;
    };
  });
}
