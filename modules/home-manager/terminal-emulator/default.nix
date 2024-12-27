{
  pkgs,
  inputs,
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
    binary = mkOption {
      type = types.str;
      default = getExe pkgs.wezterm;
    };
    name-in-shell = mkOption {
      type = types.str;
      default = "wezterm";
    };
    new-window-with-commad = mkOption {
      type = types.str;
      default = "wezterm cli spawn --new-window";
    };
    font-size = mkOption {
      type = types.str;
      default = "15.0";
    };
  };
  config = mkIf cfg.enable {
  programs.alacritty.enable = true;
    nix.settings = {
        substituters = ["https://wezterm.cachix.org"];
        trusted-public-keys = ["wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="];
    };
    programs.wezterm = {
      enable = true;
      enableZshIntegration = false; # adds weird env vars into terminal inside nvim
      package =
      if pkgs.stdenv.isLinux then inputs.wezterm-master.packages.${pkgs.system}.default else
        warn "TODO wezterm check https://github.com/NixOS/nixpkgs/issues/336069"
          inputs.nixpkgs-working-wezterm.legacyPackages.${pkgs.system}.wezterm;
      extraConfig = ''
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
          { family = "VCR OSD Mono" },
          "Noto Color Emoji",
        })

        enable_wayland = false;

        config.font_size = ${cfg.font-size}
        return config
      '';
    };
  };
}
