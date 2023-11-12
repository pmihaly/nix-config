{ lib, config, ... }:

with lib;
let cfg = config.modules.kitty;

in {
  options.modules.kitty = { enable = mkEnableOption "kitty"; };
  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      theme = "Nord";
      settings = {
        font_size = 11;
        font_family = "Iosevka Custom Bold Extended";
        bold_font = "Iosevka Custom Extrabold Extended";
        italic_font = "Iosevka Custom Bold Extended Italic";
        bold_italic_font = "Iosevka Custom Extrabold Extended Italic";
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
