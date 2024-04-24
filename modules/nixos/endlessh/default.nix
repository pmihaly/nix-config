{ lib, config, ... }:

with lib;
let
  cfg = config.modules.endlessh;
in
{
  options.modules.endlessh = {
    enable = mkEnableOption "endlessh";
  };
  config = mkIf cfg.enable {
    services.endlessh-go = {
      enable = true;
      openFirewall = true;
      port = 22;
      prometheus.enable = config.modules.monitoring.enable;
    };
  };
}
