{
  platform,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.music-production;
in
optionalAttrs platform.isLinux {
  options.modules.music-production = {
    enable = mkEnableOption "music-production";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable {
    musnix.enable = true;

    modules.backup = with config.home-manager.users.${vars.username}; {
      include = [
        "${home.homeDirectory}/.vital"
        "${home.homeDirectory}/.local/share/vital"
        "${home.homeDirectory}/.config/ardour8"
        "${home.homeDirectory}/.config/lsp-plugins"
      ];
    };

    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      home.packages = with pkgs; [
        wine
        bottles
        ardour
        vital
        lsp-plugins
        dragonfly-reverb
        calf
        dexed
        fire
        cardinal
	mixxx
      ];

      modules = {
        persistence.directories = [
          ".local/share/icons"
          ".local/share/applications"
          ".local/share/bottles"
          ".vital"
          ".local/share/vital"
          ".cache/ardour8"
          ".config/ardour8"
          ".config/lsp-plugins"
        ];
      };
    };
  };
}
