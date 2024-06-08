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
    binary = mkOption {
      type = types.str;
      default = "${pkgs.alacritty}/bin/alacritty";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      comic-code
      noto-fonts-color-emoji
      nerdfonts-fira-code
    ];

    programs.alacritty = {
      enable = true;
      settings =
        {
          font = {
            normal = {
              family = "Comic Code Ligatures";
              style = "Semibold";
            };
            italic = {
              family = "Comic Code Ligatures";
              style = "Semibold Italic";
            };
          };
          window = {
            padding = {
              x = 150;
              y = 0;
            };
            dynamic_padding = true;
            decorations = "none";
          };
          shell = {
            program = "zsh";
            args = [
              "-c"
              "tmux attach || zsh"
            ];
          };
        }
        // (builtins.fromTOML (
          builtins.readFile (
            pkgs.fetchFromGitHub {
              owner = "catppuccin";
              repo = "alacritty";
              rev = "94800165c13998b600a9da9d29c330de9f28618e";
              hash = "sha256-Pi1Hicv3wPALGgqurdTzXEzJNx7vVh+8B9tlqhRpR2Y=";
            }
            + /catppuccin-frappe.toml
          )
        ));
    };
  };
}
