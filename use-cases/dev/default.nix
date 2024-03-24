{ platform, pkgs, lib, vars, config, ... }:

with lib;
let cfg = config.modules.dev;

in optionalAttrs platform.isLinux {
  options.modules.dev = { enable = mkEnableOption "dev"; };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable {

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    home-manager.users.${vars.username}.home.packages = [ pkgs.docker-compose ];

  };
}

