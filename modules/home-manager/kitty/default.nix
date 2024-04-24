{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.kitty;
in
{
  options.modules.kitty = {
    enable = mkEnableOption "kitty";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      comic-code
      noto-fonts-color-emoji
      nerdfonts-fira-code
    ];

    programs.kitty = {
      enable = true;
      theme = "Catppuccin-Frappe";
      settings = {
        font_size = 11;
        font_family = "Comic Code Ligatures Semibold";
        bold_font = "Comic Code Ligatures Bold";
        italic_font = "Comic Code Ligatures Semibold Italic";
        bold_italic_font = "Comic Code Ligatures Bold Italic";
        window_padding_width = "0 150";
        hide_window_decorations = "titlebar-only";
        macos_option_as_alt = true;
        cursor_blink_interval = 0;
        cursor_shape = "block";
        enable_audio_bell = false;
        confirm_os_window_close = 0;
        close_on_child_death = true;
      };
      extraConfig = ''
        modify_font underline_position 1.5
        modify_font underline_thickness 140%
      '';
    };
  };
}
