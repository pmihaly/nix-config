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

    home-manager.users.${vars.username} = mkMerge [

      (optionalAttrs platform.isLinux {
        gtk = lib.mkForce {
          enable = true;
          theme = {
            name = "Catppuccin-Frappe-Standard-Mauve-Dark";
            package = pkgs.catppuccin-gtk.override {
              accents = [ "mauve" ];
              size = "standard";
              tweaks = [ "rimless" ];
              variant = "frappe";
            };
          };
          cursorTheme = {
            name = "Catppuccin-Frappe-Light-Cursors";
            package = pkgs.catppuccin-cursors.frappeLight;
          };
          iconTheme = {
            name = "Papirus";
            package = pkgs.catppuccin-papirus-folders.override {
              accent = "mauve";
              flavor = "frappe";
            };
          };
        };

      })

      {

        programs.nixvim.colorschemes.catppuccin = {
          enable = true;
          settings = {
            flavour = "frappe";
            transparent_background = true;
          };
        };

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
      }

    ];

    stylix = {
      image = ../../wallpaper.png;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-frappe.yaml";

      targets = (
        mkMerge [
          (optionalAttrs platform.isLinux { grub.enable = true; })

          { nixvim.enable = false; }
        ]
      );

      fonts = {
        emoji = {
          name = "Noto Color Emoji";
          package = pkgs.noto-fonts-color-emoji;
        };

        monospace = {
          name = "Comic Code Ligatures";
          package = pkgs.comic-code;
        };

        sansSerif = {
          name = "Noto";
          package = pkgs.noto-fonts;
        };

        serif = {
          name = "Noto Serif";
          package = pkgs.noto-fonts;
        };
      };

    };
  };
}
