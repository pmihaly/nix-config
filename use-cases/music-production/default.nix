{ platform, pkgs, lib, vars, config, ... }:

with lib;
let cfg = config.modules.music-production;

in optionalAttrs platform.isLinux {
  options.modules.music-production = {
    enable = mkEnableOption "music-production";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable {
    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      home.packages = with pkgs; [ wine bottles ];

      modules = {
        persistence.directories = [
          ".local/share/icons"
          ".local/share/applications"
          ".local/share/bottles"
        ];
      };
    };
  };
}

