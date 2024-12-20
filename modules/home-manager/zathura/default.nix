{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.zathura;
in
{
  options.modules.zathura = {
    enable = mkEnableOption "zathura";
  };
  config = mkIf cfg.enable {
    home.packages = [ pkgs.zathura ];
  };
}
