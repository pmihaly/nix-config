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

      programs.vscode.profiles.default = {
        extensions = [ pkgs.vscode-extensions.catppuccin.catppuccin-vsc-icons ];
        userSettings = {
          "workbench.iconTheme" = "catppuccin-frappe";
        };

      };

      programs.firefox.profiles.misi = {
        userChrome = mkBefore ''
          * {
            font-size:12px !important;
            font-weight: normal !important;
            font-family: "${config.stylix.fonts.monospace.name}", monospace !important;
          }'';
        extraConfig = mkBefore ''
          user_pref("font.name.serif.x-western", "${config.stylix.fonts.monospace.name}");
          user_pref("font.name.sans-serif.x-western", "${config.stylix.fonts.monospace.name}");
          user_pref("font.name.monospace.x-western", "${config.stylix.fonts.monospace.name}");
        '';
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
          nvf.enable = true;
          nushell.enable = true;
          kitty.enable = true;
          rofi.enable = true;
          fzf.enable = true;
          btop.enable = true;
          tmux.enable = true;
          bat.enable = true;
          gtk.enable = true;
          vscode = {
            enable = true;
            profileNames = [ "default" ];
          };
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
            name = "Iosevka-custom-2";
            package = (
              pkgs.iosevka.override {
                privateBuildPlan = ''
                  [buildPlans.Iosevka-custom-2]
                  family = "iosevka-custom-2"
                  spacing = "term"
                  serifs = "sans"
                  noCvSs = false
                  exportGlyphNames = true

                  [buildPlans.Iosevka-custom-2.variants]
                  inherits = "ss14"

                    [buildPlans.Iosevka-custom-2.variants.design]
                    zero = "tall-slashed"

                  [buildPlans.Iosevka-custom-2.ligations]
                  inherits = "dlig"

                  [buildPlans.Iosevka-custom-2.weights.Regular]
                  shape = 400
                  menu = 400
                  css = 400

                  [buildPlans.Iosevka-custom-2.widths.Normal]
                  shape = 500
                  menu = 5
                  css = "normal"
                '';
                set = "-custom-2";
              }
            );
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
