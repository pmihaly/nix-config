{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.tailscale;
in
{
  options.modules.tailscale = {
    enable = mkEnableOption "tailscale";
  };
  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
    };

    environment.persistence.${vars.persistDir} = {
      directories = [ "/var/lib/tailscale" ];
    };
  };
}
