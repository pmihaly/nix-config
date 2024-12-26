[
  (final: prev: {
    hanken-grotesk = (
      prev.stdenvNoCC.mkDerivation rec {
        pname = "hanken-grotesk";
        version = "1ab416e82130b2d3ddb7710abf7ceabf07156a13";

        src = prev.fetchFromGitHub {
          owner = "marcologous";
          repo = pname;
          rev = version;
          hash = "sha256-CgxqC+4QrjdsB7VdAMneP8ND9AsWPVI8d8UOn4kytxs=";
        };

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/fonts
          cp fonts/otf/*.otf $out/share/fonts

          runHook postInstall
        '';
      }
    );

    vcr-osd-mono = (
      prev.stdenvNoCC.mkDerivation {
        name = "vcr-osd-mono";

        src = prev.fetchzip {
          url = "https://dl.dafont.com/dl/?f=vcr_osd_mono";
          extension = "zip";
          hash = "sha256-6UrP5b0MUT+uoSOLzW4PwPNIst9el0ZMqhwz5BfFU+g=";
        };

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/fonts
          cp *.ttf $out/share/fonts

          runHook postInstall
        '';
      }
    );

    keepassxc =
      if !prev.stdenv.isDarwin then
        prev.keepassxc
      else
        prev.keepassxc.overrideAttrs (
          prevAttrs: finalAttrs: {
            postInstall = ''
              mkdir -p "$out/lib/mozilla/native-messaging-hosts"
              substituteAll "${./keepassxc-darwin-firefox-native-messaging-host.json}" "$out/lib/mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
            '';
          }
        );

    mpv = if !prev.stdenv.isDarwin then prev.mpv else prev.iina;
  })
]
