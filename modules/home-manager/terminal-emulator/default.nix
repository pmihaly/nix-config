{
  pkgs,
  lib,
  config,
  inputs,
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
    programs.wezterm = {
      enable = true;
      enableZshIntegration = false; # adds weird env vars into terminal inside nvim
      package = inputs.wezterm.packages.${pkgs.system}.default;
      extraConfig = ''
        local wezterm = require 'wezterm'

        local config = wezterm.config_builder()

        config.enable_tab_bar = false
        config.window_close_confirmation = 'NeverPrompt'
        config.window_decorations = 'NONE'
        config.audible_bell = 'Disabled'
        config.window_padding = {
          left = 150,
          right = 150,
          top = 5,
          bottom = 5,
        }

        config.font = wezterm.font_with_fallback({
          { family = "Comic Code Ligatures", weight = "DemiBold" },
          "Noto Color Emoji",
        })

        return config
      '';
    };
  };
}
