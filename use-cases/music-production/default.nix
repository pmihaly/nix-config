{
  platform,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.music-production;
in
optionalAttrs platform.isLinux {
  options.modules.music-production = {
    enable = mkEnableOption "music-production";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable {
    musnix.enable = true;

    modules.backup = with config.home-manager.users.${vars.username}; {
      include = [
        "${home.homeDirectory}/.vital"
        "${home.homeDirectory}/.local/share/vital"
        "${home.homeDirectory}/.config/ardour8"
        "${home.homeDirectory}/.config/lsp-plugins"
      ];
    };

    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      home.packages = with pkgs; [
        wine
        bottles
        ardour
        vital
        lsp-plugins
        dragonfly-reverb
        calf
        dexed
        fire
        cardinal
        mixxx
        geonkick
        chow-tape-model
        qdelay
        (stdenv.mkDerivation rec {
          name = "ducktool";
          src = fetchurl {
            url = "https://drive.usercontent.google.com/download?id=1HPD8plaQ-ulrn_IoFgEhCr1b0WyG-PEJ&export=download&authuser=0";
            sha256 = "01ad9n4aah07b23in6ns756sgxc4zq1bmlbnk449dprbfihcmyk3";
          };
          nativeBuildInputs = [
            makeWrapper
            unzip
          ];
          buildInputs = [
            alsa-lib
            freetype
            libglvnd
            stdenv.cc.cc.lib
            xorg.libICE
            xorg.libSM
            xorg.libX11
            xorg.libXext
            zlib
            fontconfig
          ];

          unpackPhase = ''
            unzip $src
          '';

          installPhase = ''
            mkdir -p $out/lib/vst3
            cp -r ducktool-linux/VST3/* $out/lib/vst3
          '';
          postFixup = ''
            patchelf --set-rpath "${lib.makeLibraryPath buildInputs}" $out/lib/vst3/DuckTool.vst3/Contents/x86_64-linux/DuckTool.so
          '';
        })
        (stdenv.mkDerivation rec {
          name = "byod";
          src = fetchurl {
            url = "https://release-assets.githubusercontent.com/github-production-release-asset/378525798/323bc5e8-2bac-478a-a9ac-5e5eb11cf8e0";
            sha256 = "sha256-wYA65Xtxe6sE7yBywQKEvLfUT741LUJkUHWwxodcmus=";
          };
          nativeBuildInputs = [
            makeWrapper
            unzip
          ];
          buildInputs = [
            alsa-lib
            freetype
            libglvnd
            stdenv.cc.cc.lib
            xorg.libICE
            xorg.libSM
            xorg.libX11
            xorg.libXext
            zlib
            fontconfig
          ];

          unpackPhase = ''
            ar x $src
	    tar -xf data.tar.xz
          '';

          installPhase = ''
            mkdir -p $out/lib/vst3
            cp -r usr/lib/vst3/BYOD.vst3 $out/lib/vst3
          '';
          postFixup = ''
            patchelf --set-rpath "${lib.makeLibraryPath buildInputs}" $out/lib/vst3/BYOD.vst3/Contents/x86_64-linux/BYOD.so
          '';
        })
      ];

      modules = {
        persistence.directories = [
          ".local/share/icons"
          ".local/share/applications"
          ".local/share/bottles"
          ".local/share/geonkick"
          ".vital"
          ".local/share/vital"
          ".cache/ardour8"
          ".config/ardour8"
          ".config/lsp-plugins"
          ".config/geonkick"
        ];
      };
    };
  };
}
