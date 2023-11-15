{ lib, config, ... }:

with lib;
let cfg = config.modules.jellyfin;

in {
  options.modules.jellyfin = { enable = mkEnableOption "jellyfin"; };
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
