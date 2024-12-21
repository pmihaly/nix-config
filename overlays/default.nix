[
  (final: prev: {
    nerdfonts-fira-code = prev.nerdfonts.override { fonts = [ "FiraCode" ]; };

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

    iosevka-custom = prev.iosevka.override {
      privateBuildPlan = ''
        [buildPlans.Iosevka-custom]
        family = "Iosevka Custom"
        spacing = "fontconfig-mono"
        serifs = "slab"
        noCvSs = true
        exportGlyphNames = true

          [buildPlans.Iosevka-custom.ligations]
          inherits = "dlig"

        [buildPlans.Iosevka-custom.weights.regular]
        shape = 400
        menu = 400
        css = 400

        [buildPlans.Iosevka-custom.weights.bold]
        shape = 700
        menu = 700
        css = 700

        [buildPlans.Iosevka-custom.weights.extrabold]
        shape = 800
        menu = 800
        css = 800

        [buildPlans.Iosevka-custom.weights.heavy]
        shape = 900
        menu = 900
        css = 900

        [buildPlans.Iosevka-custom.slopes.upright]
        angle = 0
        shape = "upright"
        menu = "upright"
        css = "normal"

        [buildPlans.Iosevka-custom.slopes.italic]
        angle = 9.4
        shape = "italic"
        menu = "italic"
        css = "italic"
      '';
      set = "-custom";
    };

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
