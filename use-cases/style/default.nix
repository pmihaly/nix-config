{
  platform,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.style;
in
{
  options.modules.style = {
    enable = mkEnableOption "style";
  };
  config = mkIf cfg.enable {
    home-manager.users.${vars.username} = {
      programs.nixvim.colorschemes.nord.enable = true;

      programs.newsboat.extraConfig =
        (builtins.readFile (
          pkgs.fetchFromGitHub {
            owner = "catppuccin";
            repo = "newsboat";
            rev = "be3d0ee1ba0fc26baf7a47c2aa7032b7541deb0f";
            hash = "sha256-czvR3bVZ0NfBmuu0JixalS7B1vf1uEGSTSUVVTclKxI=";
          }
          + /themes/dark
        ))
        + ''
          color listfocus          default color0 bold
          color listfocus_unread   color2  color0 bold
        '';

      programs.vscode = {
        extensions = [ pkgs.vscode-extensions.catppuccin.catppuccin-vsc-icons ];
        userSettings = {
          "workbench.iconTheme" = "catppuccin-frappe";
        };
      };

      stylix = {
        enable = true;
        autoEnable = false;
        image = ../../wallpaper.png;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
        # https://stylix.danth.me/?search=
        targets = {
          firefox = {
            enable = true;
            profileNames = [ "misi" ];
          };
          yazi.enable = true;
          zathura.enable = true;
          kitty.enable = true;
          rofi.enable = true;
          fzf.enable = true;
          btop.enable = true;
          tmux.enable = true;
          bat.enable = true;
          gtk.enable = true;
          vscode.enable = true;
        };
      };
    };

    stylix = mkMerge [
      {
        enable = true;
        autoEnable = false;
        image = ../../wallpaper.png;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";

        fonts = {
          emoji = {
            name = "Noto Color Emoji";
            package = pkgs.noto-fonts-color-emoji;
          };

          monospace = {
            name = "VCR OSD Mono";
            package = pkgs.vcr-osd-mono;
          };

          sansSerif = {
            name = "Hanken Grotesk";
            package = pkgs.hanken-grotesk;
          };

          serif = {
            name = "Hanken Grotesk";
            package = pkgs.hanken-grotesk;
          };
        };
      }

      (optionalAttrs platform.isLinux {
        targets = {
          console.enable = true;
        };
      })
    ];
  };
}
