{ platform, inputs, pkgs, vars, lib, config, ... }:

with lib;
let cfg = config.modules.nix;

in {
  options.modules.nix = { enable = mkEnableOption "nix"; };
  config = mkIf cfg.enable (mkMerge [
    {
      nixpkgs.overlays = import ../../overlays;

      nixpkgs.config.allowUnfree = true;
      documentation.enable = false;

      nix = {
        settings.experimental-features = "nix-command flakes";
        settings.auto-optimise-store = true;
        gc.automatic = true;
      };

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;

      home-manager.users.${vars.username} = {
        imports = [
          inputs.agenix.homeManagerModules.default
          inputs.nix-index-database.hmModules.nix-index
          ../../secrets/home-manager
        ];

        home.packages =
          [ inputs.agenix.packages."${pkgs.system}".default pkgs.deploy-rs ];

        programs.nix-index-database.comma.enable = true;

        modules.persistence.directories = [ ".nix-config" ];
      };
    }

    (optionalAttrs platform.isLinux { nix.gc.dates = "weekly"; })

    (optionalAttrs platform.isDarwin {
      services.nix-daemon.enable = true;
      homebrew = {
        enable = true;
        onActivation = {
          upgrade = true;
          cleanup = "zap";
        };
      };

      nix.gc = {
        interval = {
          Hour = 3;
          Minute = 15;
        };
        user = vars.username;
      };
    })
  ]);
}

