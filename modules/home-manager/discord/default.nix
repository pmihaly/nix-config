{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.discord;
in
{
  options.modules.discord = {
    enable = mkEnableOption "discord";
  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [ ".config/discord" ];

    home.packages = [ pkgs.discord ];
  };
}
