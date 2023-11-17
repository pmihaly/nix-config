{ lib, config, ... }:

with lib;
let cfg = config.modules.jellyfin;

in {
  options.modules.jellyfin = { enable = mkEnableOption "jellyfin"; };
  config = mkIf cfg.enable {
    services.nginx = {
      virtualHosts."jellyfin.skylake.mihaly.codes" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://localhost:8096";
        };
      };
    };

    modules.homer.services.Media.Jellyfin = {
      logo = ./jellyfin.png;
      url = "https://jellyfin.skylake.mihaly.codes";
    };

    services.jellyfin = {
      enable = true;
    };

  };
}
