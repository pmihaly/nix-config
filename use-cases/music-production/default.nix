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

  # nixpkgs installs liblsp-r3d-glx-lib.so only flat in $out/lib, but LSP
  # discovers its 3D (r3d/GLX) backend by scanning the directory of the
  # currently loaded plugin module. The official release ships the backend lib
  # INSIDE every plugin bundle (LV2/VST2/VST3/CLAP dirs); without it the Room
  # Builder's 3D view silently has no backend (blank canvas) in Ardour. Re-ship
  # the package with the backend lib also placed in each bundle dir (verified
  # against lsp-plugins 1.2.34 + Ardour 8.12).
  lspPluginsR3dFixed = pkgs.stdenv.mkDerivation {
    name = "lsp-plugins-r3d-${pkgs.lsp-plugins.version}";
    dontUnpack = true;
    buildInputs = [ ];
    installPhase = ''
      cp -rL --no-preserve=mode --no-preserve=ownership "${pkgs.lsp-plugins}" "$out"
      for dir in lib/lv2/lsp-plugins.lv2 lib/vst/lsp-plugins.vst lib/vst3/lsp-plugins.vst3/Contents/x86_64-linux lib/clap; do
        install -Dm555 "${pkgs.lsp-plugins}/lib/liblsp-r3d-glx-lib.so" "$out/$dir/liblsp-r3d-glx-lib.so"
      done
    '';
  };

  # Vital freeze -- FULL root cause (2026-10-13, aesop, niri/XWayland):
  # adding a Vital instance freezes Ardour. gdb breakpoint on exit() shows
  # the chain:
  #   VST3Plugin::has_editor -> try_create_view -> juce::Desktop::Desktop()
  #     -> GetXProperty(root, workAreaHints = None, ...)   [BadAtom!]
  #   -> gdk_x_error (libydk fatal X handler) -> exit()
  #   -> _dl_fini -> libardour.so.3 global dtors -> __cxa_finalize
  #   -> pthread_cond_destroy  (blocks forever: Ardour's own worker threads
  #     -- SessionSignals, AutoConnect, DeviceList, EngineWatchdog, Analyzer --
  #     are still waiting on that condvar; glibc's pthread_cond_destroy waits
  #     for waiters to leave, and nobody signals them).
  # The BadAtom is Vital's bundled JUCE bug: findDisplays() (XRANDR path)
  # passes an UNCHECKED _NET_WORKAREA atom to XGetWindowProperty; niri's
  # XWayland does not define _NET_WORKAREA, so XInternAtom(..., True) returns
  # None and the call errors. Upstream mtytel/vital master still has it.
  #
  # Fix: the ardour-vst wrapper (modules/home-manager/music-production)
  # preloads xerror-shield.so, a tiny lib that swaps any X error handler for
  # a lenient one (log + return 0) -- exactly how standalone Vital survives.
  #
  # Reverted to the nixpkgs build (1.5.5): the 1.6.4 override (2026-10-04)
  # did NOT affect this (same bundled-JUCE bug, unfixed up to 1.6.4, and the
  # Ardour-side exit-path deadlock also needs reporting). Report upstream:
  # mtytel/vital (Juce workAreaHints None guard) and Ardour (exit-path
  # deadlock -- global dtors must not destroy condvars with live waiters).

  # Official release AppImage run via appimage-run (same pattern as minecraft).
  noiseCanvas = pkgs.writeShellScriptBin "noise-canvas" ''
    ${getExe pkgs.appimage-run} ${
      builtins.fetchurl {
        url = "https://github.com/robclouth/noise-canvas/releases/download/v1.0.3/noise-canvas-linux.AppImage";
        sha256 = "sha256-+nopbzy50UAsIFtSWgoyYawPuenBkZx+x1Es0MhPTMo=";
      }
    }
  '';
in
optionalAttrs platform.isLinux {
  options.modules.music-production = {
    enable = mkEnableOption "music-production";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable {
    # KONTAKT 8 + wine: the two wine paths are SPLIT on purpose. The VST
    # bottle/standalone runs wine staging (11.16) -- Kontakt runs cleanly and
    # its file dialogs work (wine 9.21, the 'yabridge' wineRelease, hard-
    # crashes Kontakt's file/Load dialog in comdlg32). The BRIDGED path
    # (yabridge in Ardour) runs wine 9.21 again: with 11.x every yabridge-
    # hosted window had a constant ~100px vertical cursor offset on
    # niri/XWayland (verified 2026-09-24; kool kordz worked on 9.21). 9.21's
    # comdlg32 crash is moot for the bridged path -- the bobdule build has no
    # ni-platform.dll, so Kontakt's internal Load browser is a no-op anyway,
    # and instruments are opened via kontakt-open (argv). Nothing re-migrates
    # when a plugin loads: bottle and bridged host never share a prefix boot.
    #
    # Implementation: no overlay. nixpkgs' yabridge package hardcodes
    # WINELOADER to wineWow64Packages.yabridge at build time, so leaving that
    # attr as the genuine 9.21 build makes the bridged host use 9.21; the
    # bottle/standalone side picks staging explicitly in
    # modules/home-manager/music-production (winePkg =
    # wineWow64Packages.staging).

    musnix.enable = true;

    # Never let the Digitakt's USB audio interface become the default output /
    # input. WirePlumber's ALSA monitor scores devices by priority.session (see
    # scripts/monitors/alsa.lua: usb +100, analog +9, capture +1000), so the
    # Digitakt (~1109 sink / ~2109 source) outranks the built-in HDMI card
    # (~700) and wins find-best-default-node on hotplug. A negative session
    # priority can never win that selection, so plugging the Digitakt in no
    # longer hijacks the default sink+source -- it stays fully available as an
    # explicit target (Ardour, digitakt-bounce) and only becomes default if
    # the user deliberately picks it (wpctl/pavucontrol).
    services.pipewire.wireplumber.extraConfig = {
      "99-digitakt-never-default" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_(output|input)\\.usb-Elektron_Music_Machines_Elektron_Digitakt.*"; }
            ];
            actions = {
              "update-props" = {
                "priority.session" = -1000;
              };
            };
          }
        ];
      };
    };

    modules.backup = with config.home-manager.users.${vars.username}; {
      include = [
        "${home.homeDirectory}/.vital"
        "${home.homeDirectory}/.local/share/vital"
        "${home.homeDirectory}/.config/ardour9"
        "${home.homeDirectory}/.cache/ardour9"
        "${home.homeDirectory}/.config/lsp-plugins"
      ];
    };

    home-manager.users.${vars.username} = {
      imports = [
        ../../modules/home-manager
        ../../modules/home-manager/music-production
      ];

      home.packages = with pkgs; [
        wine
        bottles
        # Windows VSTs in Ardour: yabridge bridges Windows .dll (VST2) / .vst3
        # plugins into Linux DAWs. The nixpkgs build is patched for NixOS:
        #   - chainloaders find libyabridge via $NIX_PROFILES (no /usr/lib)
        #   - yabridge-host.exe is run with a bundled wow64 (multilib) wine
        # The Bottles bottle "VST" is created declaratively (wineboot) by the
        # music-production module and uses the same wine yabridge runs with.
        # The vst-bottle systemd user service (login) mirrors the bottle's
        # 64-bit plugins into ~/.local/share/bottles/vst-windows -- deliberately
        # NOT ~/.vst / ~/.vst3, which Ardour's VST3 scanner always walks (a raw
        # Windows PE there fails with "invalid ELF header") -- and re-syncs the
        # yabridge shims in ~/.vst{,3}/yabridge.
        # Workflow:
        #   1. vst-run <path>/Setup.exe   to install a Windows VST into the bottle
        #   2. (the login service auto-syncs; or run: yabridge-sync)
        #   3. ardour-vst (or the "Ardour" desktop/app-menu entry) to launch
        #      Ardour with the bottle's WINEPREFIX; under ~/.vst{,3} Ardour finds
        #      only the yabridge shims (plus the ~/.vst3/nix native bundles)
        yabridge
        yabridgectl
        ardour
        pkgs.vital
        lspPluginsR3dFixed
        dragonfly-reverb
        calf
        dexed
        fire
        cardinal
        mixxx
        noiseCanvas
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
            libice
            libsm
            libx11
            libxext
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
            libice
            libsm
            libx11
            libxext
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

      xdg.desktopEntries.noise-canvas = {
        name = "Noise Canvas";
        comment = "Photoshop for sound";
        categories = [
          "AudioVideo"
          "Audio"
        ];
        exec = getExe noiseCanvas;
      };

      modules = {
        # Declarative wine bottle for Windows VSTs (modules/home-manager/music-production)
        music-production.wine.enable = true;

        persistence.directories = [
          ".local/share/icons"
          ".local/share/applications"
          ".local/share/bottles"
          ".local/share/geonkick"
          ".vital"
          ".local/share/vital"
          ".cache/ardour9"
          ".config/ardour9"
          ".config/lsp-plugins"
          ".config/geonkick"
          # Windows VSTs via yabridge (shim + config state). The yabridge
          # sources live under .local/share/bottles (already persisted below),
          # not in ~/.vst / ~/.vst3 which Ardour scans.
          ".wine"
          ".vst"
          ".vst3"
          ".config/yabridgectl"
        ];
      };
    };
  };
}
