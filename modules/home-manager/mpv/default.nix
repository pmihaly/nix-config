{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.mpv;
in
{
  options.modules.mpv = {
    enable = mkEnableOption "mpv";
  };
  config = mkIf cfg.enable {

    home.packages = with pkgs; [ material-icons ];

    programs.mpv = {
      enable = true;
      config = {
        ytdl-format = "bestvideo+bestaudio/best";
      };
      defaultProfiles = [ "gpu-hq" ];
      scripts = with pkgs.mpvScripts; [ uosc ];
      bindings = {
        "l" = "seek 5";
        "h" = "seek -5";
        "j" = "seek -60";
        "k" = "seek 60";

        "s" = "cycle sub";
        "a" = "cycle audio";

        "Alt+h" = "add chapter -1";
        "Alt+l" = "add chapter 1";
        "Ctrl+SPACE" = "add chapter 1";

        "Alt+j" = "add video-zoom -0.25";
        "Alt+k" = "add video-zoom 0.25";

        "Alt+J" = "add sub-pos -1";
        "Alt+K" = "add sub-pos +1";

        "Ctrl+h" = "multiply speed 1/1.1";
        "Ctrl+l" = "multiply speed 1.1";
        "Ctrl+H" = "set speed 1.0";
      };
    };
  };
}
