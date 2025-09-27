{
  platform,
  inputs,
  pkgs,
  vars,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.gaming;
in
optionalAttrs platform.isLinux {
  options.modules.gaming = {
    enable = mkEnableOption "gaming";
  };
  imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];
  config = mkIf cfg.enable {

    programs.steam = {
      enable = true;

      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      home.packages = with pkgs; [
        lutris
        wine
        winetricks
        gamescope
        gamemode
        mangohud
        protontricks
      ];

      modules = {
        discord.enable = true;
        minecraft.enable = true;
        persistence.directories = [
          ".config/lutris"
          ".local/share/lutris"
          ".local/share/icons"
          ".local/share/applications" # lutris application menu shortcuts

          ".steam"
          ".local/share/Steam"
          ".local/share/Terraria"
        ];
      };
    };

    security.rtkit.enable = true;

    nix.settings = {
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
    };
  };
}
