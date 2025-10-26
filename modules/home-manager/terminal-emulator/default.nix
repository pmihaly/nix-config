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
      default = getExe config.programs.kitty.package;
    };
    name-in-shell = mkOption {
      type = types.str;
      default = "kitty";
    };
    new-window-with-commad = mkOption {
      type = types.str;
      default = "kitty";
    };
    font-size = mkOption {
      type = types.str;
      default = "15.0";
    };
  };
  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      font.name = "VCR OSD Mono";
      font.package = pkgs.vcr-osd-mono;
      settings = {
        macos_option_as_alt = true;
        macos_quit_when_last_window_closed = true;
        focus_follows_mouse = true;
        font_size = cfg.font-size;
        copy_on_select = true;
        confirm_os_window_close = "0";
        enable_audio_bell = false;
      };
      keybindings = {
        "ctrl+enter" = "";
        "cmd+enter" = "";
      };
    };
  };
}
