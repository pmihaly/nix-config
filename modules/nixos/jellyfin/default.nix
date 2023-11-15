{ lib, config, ... }:

with lib;
let cfg = config.modules.homer;

in {
  options.modules.homer = { enable = mkEnableOption "homer"; };
  config = mkIf cfg.enable {
    services.nginx = {
      virtualHosts.localhost.locations."^~ /jellyfin" = {
        proxyPass = "http://localhost:8096/";
      };
    };

    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

  };
}
