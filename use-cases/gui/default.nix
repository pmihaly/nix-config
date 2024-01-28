{ inputs, platform, pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.gui;

in {
  options.modules.gui = {
    enable = mkEnableOption "gui";
    username = mkOption { type = types.str; };
  };

  imports = [ ./darwin.nix ./linux.nix ];

  config = mkIf cfg.enable (mkMerge [

    {
      home-manager.users.${cfg.username} = {
        imports = [ ../../modules/home-manager ];

        modules = {
          firefox.enable = true;
          mpv.enable = true;
          kitty.enable = true;
          newsboat.enable = true;
          neomutt.enable = true;
          zathura.enable = true;
        };

        home.packages = with pkgs; [
          keepassxc
          syncthing
          act # running github actions locally
          nix-tree # visualisation of nix derivations
          keepass-diff # diffing .kdbx files
          inputs.img2theme.packages."${pkgs.system}".default
          yt-dlp
          feh
        ];
      };
    }

    (optionalAttrs platform.isLinux {
      modules.linux = {
        enable = true;
        username = cfg.username;
      };
    })

    (optionalAttrs platform.isDarwin { modules.darwin.enable = true; })
  ]);
}

