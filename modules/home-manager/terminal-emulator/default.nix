{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.terminal-emulator;
in
{
  options.modules.terminal-emulator = {
    enable = mkEnableOption "terminal-emulator";
    binary = mkOption { type = types.str; };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      comic-code
      noto-fonts-color-emoji
      nerdfonts-fira-code
    ];

    programs.wezterm = {
      enable = true;
      enableZshIntegration = true;
      extraConfig = ''
        local wezterm = require 'wezterm'

        local config = wezterm.config_builder()

        config.color_scheme = 'Catppuccin Frappe'
        config.enable_tab_bar = false
        config.window_close_confirmation = 'NeverPrompt'
        config.window_decorations = 'RESIZE'
        config.audible_bell = 'Disabled'
        config.window_padding = {
          left = 150,
          right = 150,
          top = 0,
          bottom = 0,
        }

        config.font = wezterm.font_with_fallback({
          { family = "Comic Code Ligatures", weight = "DemiBold" },
          "Noto Color Emoji",
        })

        return config
      '';
      colorSchemes = {
        catppuccin = (
          builtins.fromTOML (
            builtins.readFile (
              pkgs.fetchFromGitHub {
                owner = "catppuccin";
                repo = "wezterm";
                rev = "b1a81bae74d66eaae16457f2d8f151b5bd4fe5da";
                sha256 = "sha256-McSWoZaJeK+oqdK/0vjiRxZGuLBpEB10Zg4+7p5dIGY=";
              }
              + /dist/catppuccin-frappe.toml
            )
          )
        );
      };
    };
  };
}
