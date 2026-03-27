{
  platform,
  pkgs,
  lib,
  vars,
  config,
  inputs,
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
        "${home.homeDirectory}/.cache/ardour8"
        "${home.homeDirectory}/.config/lsp-plugins"
      ];
    };

    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      home.packages = with pkgs; [
        wine
        bottles
        ardour_8
        # ardour
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
        inputs.nixpkgs-working-elektroid.legacyPackages."x86_64-linux".elektroid
        # paulstretch
        distrobox
        # (stdenv.mkDerivation {
        #  pname = "paulstretch";
        #  version = "2.2-2";
        #
        #  src = fetchFromGitHub {
        #    owner = "paulnasca";
        #    repo = "paulstretch_cpp";
        #    rev = "7d0b60b5e1f73968e982c85d979f3b9edccd18c6";
        #    sha256 = "RJbexvT0IFK5xbInSh1qFryySib/skrKnj4fmnrz46Y=";
        #  };
        #
        #  nativeBuildInputs = [ pkg-config ];
        #
        #  buildInputs = [
        #    audiofile
        #    libvorbis
        #    fltk
        #    fftw
        #    fftwFloat
        #    minixml
        #    libmad
        #    libjack2
        #    portaudio
        #    libsamplerate
        #  ];
        #
        #  patches = [
        #    # https://github.com/paulnasca/paulstretch_cpp/pull/12
        #    (fetchpatch {
        #      url = "https://github.com/paulnasca/paulstretch_cpp/commit/d8671b36135fe66839b11eadcacb474cc8dae0d1.patch";
        #      sha256 = "0lx1rfrs53afkiz1drp456asqgj5yv6hx3lkc01165cv1jsbw6q4";
        #    })
        #  ];
        #
        #  buildPhase = ''
        #    bash compile_linux_fftw_jack.sh
        #  '';
        #
        #  installPhase = ''
        #    install -Dm555 ./paulstretch $out/bin/paulstretch
        #  '';
        #
        #  meta = {
        #    description = "Produces high quality extreme sound stretching";
        #    longDescription = ''
        #      This is a program for stretching the audio. It is suitable only for
        #      extreme sound stretching of the audio (like 50x) and for applying
        #      special effects by "spectral smoothing" the sounds.
        #      It can transform any sound/music to a texture.
        #    '';
        #    homepage = "https://github.com/paulnasca/paulstretch_cpp/";
        #    platforms = lib.platforms.linux;
        #    license = lib.licenses.gpl2;
        #    mainProgram = "paulstretch";
        #  };})
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
            url = "https://github.com/Chowdhury-DSP/BYOD/releases/download/v1.3.0/BYOD-Linux-x64-1.3.0.deb";
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
        (stdenv.mkDerivation rec {
          name = "overwitch";
          src = fetchFromGitHub {
            owner = "dagargo";
            repo = "overwitch";
            rev = "2.2";
            sha256 = "sha256-EYT5m4N9kzeYaOcm1furGGxw1k+Bw+m+FvONVZN9ohk=";
          };
          nativeBuildInputs = with pkgs; [
            pkg-config
            autoreconfHook
            wrapGAppsHook3
          ];

          buildInputs = with pkgs; [
            libtool
            libusb1
            libjack2
            libsamplerate
            libsndfile
            gettext
            json-glib
            gtk4
          ];

          postInstall = ''
            # install udev/hwdb rules
            mkdir -p $out/etc/udev/rules.d/
            mkdir -p $out/etc/udev/hwdb.d/
            cp ./udev/*.hwdb $out/etc/udev/hwdb.d/
            cp ./udev/*.rules $out/etc/udev/rules.d/
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
