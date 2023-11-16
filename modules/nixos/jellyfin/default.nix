{ lib, config, ... }:

with lib;
let cfg = config.modules.jellyfin;

in {
  options.modules.jellyfin = { enable = mkEnableOption "jellyfin"; };
  config = mkIf cfg.enable {
    services.nginx = {
      virtualHosts."jellyfin.skylake.mihaly.codes".locations."/" = {
        proxyPass = "http://localhost:8096";
      };
    };

    services.jellyfin = {
      enable = true;
    };

  };
}
