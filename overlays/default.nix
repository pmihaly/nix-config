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

    futuristic-iosevka = (
      # use light as regular and regular as bold
      prev.iosevka.override {
        privateBuildPlan = ''
          [buildPlans.Iosevka-custom]
          family = "iosevka-custom"
          spacing = "normal"
          serifs = "sans"
          noCvSs = true
          exportGlyphNames = false

            [buildPlans.Iosevka-custom.variants]
            inherits = "ss07"

          [buildPlans.Iosevka-custom.weights.Light]
          shape = 200
          menu = 200
          css = 200

          [buildPlans.Iosevka-custom.weights.Regular]
          shape = 500
          menu = 500
          css = 500

          [buildPlans.Iosevka-custom.widths.Normal]
          shape = 500
          menu = 5
          css = "normal"
        '';
        set = "-custom";
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
  })
]
