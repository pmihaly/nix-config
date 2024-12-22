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
    browser-hintchars = mkOption {
      type = types.str;
      default = "jfkdls;a";
    };
    terminal-font-size = mkOption {
      type = types.str;
      default = "12.0";
    };
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
          firefox = {
            enable = true;
            hintchars = cfg.browser-hintchars;
          };
          mpv.enable = true;
          terminal-emulator = {
            enable = true;
            font-size = cfg.terminal-font-size;
          };
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
          feh
          tailscale
        ];
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
