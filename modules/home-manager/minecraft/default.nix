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
        url = "https://github.com/PolyMC/PolyMC/releases/download/7.0/PolyMC-Linux-7.0-x86_64.AppImage";
        sha256 = "1xz91mjzc9rm50n6viqxjgjvlqi4mdkf21xzld6idr9wp1j3vyqi";
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
