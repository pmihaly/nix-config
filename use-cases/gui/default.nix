{
  inputs,
  platform,
  pkgs,
  vars,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.gui;
in
{
  options.modules.gui = {
    enable = mkEnableOption "gui";
  };

  imports = [
    ./darwin
    ./linux.nix
  ];

  config = mkIf cfg.enable (mkMerge [

    {
      home-manager.users.${vars.username} = {
        imports = [ ../../modules/home-manager ];

        modules = {
          persistence.directories = [
            "Downloads"
            "Music"
            "Pictures"
            "Documents"
            "Videos"
          ];
          firefox.enable = true;
          mpv.enable = true;
          terminal-emulator.enable = true;
          newsboat.enable = true;
          neomutt.enable = true;
          zathura.enable = true;
          keepassxc.enable = true;
        };

        home.packages = with pkgs; [
          syncthing
          act # running github actions locally
          nix-tree # visualisation of nix derivations
          keepass-diff # diffing .kdbx files
          inputs.img2theme.packages."${pkgs.system}".default
          yt-dlp
          feh
          tailscale
        ];
      };
    }

    {
      nix.settings = {
        substituters = [ "https://nix-gaming.cachix.org" ];
        trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
      };
    }

    (optionalAttrs platform.isLinux {
      modules.linux = {
        enable = true;
        username = vars.username;
      };
    })

    (optionalAttrs platform.isDarwin { modules.darwin.enable = true; })
  ]);
}
