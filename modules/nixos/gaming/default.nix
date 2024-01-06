{ inputs, pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.gaming;

in {
  options.modules.gaming = { enable = mkEnableOption "gaming"; };
  imports = [
    inputs.nix-gaming.nixosModules.pipewireLowLatency
    inputs.nix-gaming.nixosModules.steamCompat
  ];
  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.lutris pkgs.wine pkgs.gamescope ];

    programs.steam = {
      enable = true;

      extraCompatPackages =
        [ inputs.nix-gaming.packages.${pkgs.system}.proton-ge ];
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      lowLatency = {
        enable = true;
        quantum = 64;
        rate = 48000;
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
