{ platform, inputs, lib, config, ... }:

with lib;
let cfg = config.modules.nix;

in {
  options.modules.nix = {
    enable = mkEnableOption "nix";
    username = mkOption { type = types.str; };
  };
  config = mkIf cfg.enable (mkMerge [

    (optionalAttrs platform.isDarwin { services.nix-daemon.enable = true; })

    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }

    {
      home-manager.users.${cfg.username} = {
        imports = [
          inputs.agenix.homeManagerModules.default
          ../../secrets/home-manager
        ];
      };
    }

    (optionalAttrs platform.isDarwin {
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
        user = cfg.username;
      };
    })

    (optionalAttrs platform.isLinux { nix.gc.dates = "weekly"; })

    {
      nixpkgs.config.allowUnfree = true;
      documentation.enable = false;

      nixpkgs.overlays = import ../../overlays;

      nix = {
        settings.experimental-features = "nix-command flakes";
        settings.auto-optimise-store = true;
        gc.automatic = true;
      };
    }

  ]);
}

