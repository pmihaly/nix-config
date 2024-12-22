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
    font-size = mkOption {
      type = types.str;
      default = "12.0";
    };
  };
  config = mkIf cfg.enable {
    programs.wezterm = {
      enable = true;
      enableZshIntegration = false; # adds weird env vars into terminal inside nvim
      package = inputs.wezterm.packages.${pkgs.system}.default;
      extraConfig = concatStringsSep "\n" [
        ''
          local wezterm = require 'wezterm'

          local config = wezterm.config_builder()

          config.enable_tab_bar = false
          config.window_close_confirmation = 'NeverPrompt'
          config.audible_bell = 'Disabled'
          config.window_padding = {
            left = 150,
            right = 150,
            top = 5,
            bottom = 5,
          }

          config.font = wezterm.font_with_fallback({
            { family = "Monocraft" },
            "Noto Color Emoji",
          })

          config.font_size = ${cfg.font-size};
        ''

        (
          if pkgs.stdenv.isDarwin then
            ""
          else
            # doesnt work on macos (+ aerospace)
            "config.window_decorations = 'NONE'"
        )

        "return config"
      ];
    };
  };
}
