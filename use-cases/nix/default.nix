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
  cfg = config.modules.nix;
in
{
  options.modules.nix = {
    enable = mkEnableOption "nix";
  };
  config = mkIf cfg.enable (mkMerge [
    {
      nixpkgs.overlays = import ../../overlays;

      nixpkgs.config.allowUnfree = true;
      documentation.enable = false;

      nix = {
        nixPath = [ "nixpkgs=/etc/channels/nixpkgs" ];
        settings = {
          experimental-features = "nix-command flakes pipe-operators";
          trusted-users = [ vars.username ];
        };
        gc.automatic = true;
      };

      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      environment.etc."channels/nixpkgs".source = inputs.nixpkgs.outPath;

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;

      home-manager.users.${vars.username} = {
        imports = [
          inputs.agenix.homeManagerModules.default
          inputs.nixvim.homeManagerModules.default
          inputs.nix-index-database.hmModules.nix-index
          ../../secrets/home-manager
        ];

        home.packages = with pkgs; [
          inputs.agenix.packages."${pkgs.system}".default
          deploy-rs
          nix-tree # visualisation of nix derivations
        ];

        programs.nix-index-database.comma.enable = true;

        modules.persistence.directories = [ ".nix-config" ];
      };
    }

    (optionalAttrs platform.isLinux { nix.gc.dates = "weekly"; })

    (optionalAttrs platform.isDarwin {
      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          cleanup = "zap";
        };
      };
    })
  ]);
}
