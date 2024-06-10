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
