{ platform, inputs, pkgs, vars, lib, config, ... }:

with lib;
let cfg = config.modules.gaming;

in optionalAttrs platform.isLinux {
  options.modules.gaming = { enable = mkEnableOption "gaming"; };
  imports = [
    inputs.nix-gaming.nixosModules.pipewireLowLatency
    inputs.nix-gaming.nixosModules.steamCompat
  ];
  config = mkIf cfg.enable {

    environment.systemPackages =
      [ pkgs.lutris pkgs.wine pkgs.gamescope pkgs.gamemode ];

    programs.steam = {
      enable = true;

      extraCompatPackages =
        [ inputs.nix-gaming.packages.${pkgs.system}.proton-ge ];
    };

    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      modules = {
        discord.enable = true;
        minecraft.enable = true;
        persistence.directories = [
          ".config/lutris"
          ".local/share/lutris"
          ".local/share/icons"

          ".steam"
        ];

      };
    };

    security.rtkit.enable = true;

    nix.settings = {
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      ];
    };

  };
}
