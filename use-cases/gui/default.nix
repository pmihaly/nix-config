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
      default = "jkdls;a";
    };
    terminal-font-size = mkOption {
      type = types.str;
      default = "15.0";
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
            ".config/transmission"
            ".local/state/syncthing"
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
          email.enable = true;
          keepassxc.enable = true;
        };

        services.syncthing.enable = true;

        home.packages = with pkgs; [
          keepass-diff # diffing .kdbx files
          inputs.img2theme.packages."${pkgs.system}".default
          feh
          tailscale
          transmission_4-gtk
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
