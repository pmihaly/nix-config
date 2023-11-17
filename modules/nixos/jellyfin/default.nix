{ lib, config, ... }:

with lib;
let cfg = config.modules.jellyfin;

in {
  options.modules.jellyfin = { enable = mkEnableOption "jellyfin"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "jellyfin";
    port = 8096;
    dashboard = {
      category = "Media";
      name = "Jellyfin";
      logo = ./jellyfin.png;
    };
    extraConfig = { services.jellyfin.enable = true; };
  });
}
