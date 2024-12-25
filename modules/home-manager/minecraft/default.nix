{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.minecraft;
  mcScript = pkgs.writeShellScriptBin "minecraft" ''
    ${getExe pkgs.appimage-run} ${
      builtins.fetchurl {
        url = "https://github.com/PolyMC/PolyMC/releases/download/6.1/PolyMC-Linux-6.1-x86_64.AppImage";
        sha256 = "0hzfa5b4rmkj4g7y0j774lzfjjlpipq3ps13d9vmaj4g4nsqm46i";
      }
    }
  '';
in
{
  options.modules.minecraft = {
    enable = mkEnableOption "minecraft";
  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [
      ".cache/appimage-run"
      ".local/share/PolyMC"
    ];

    home.packages = [
      pkgs.temurin-jre-bin-21
      mcScript
    ];

    xdg.desktopEntries.minecraft = {
      name = "Minecraft";
      categories = [ "Game" ];
      exec = getExe mcScript;
    };
  };
}
