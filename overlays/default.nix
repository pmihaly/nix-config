[
  (final: prev: {
    nerdfonts-fira-code = prev.nerdfonts.override {
      fonts = [ "FiraCode" ];
    };
  })
  (final: prev: {
    iosevka-custom = prev.iosevka.override {
      privateBuildPlan = ''
        [buildPlans.iosevka-custom]
        family = "Iosevka Custom"
        spacing = "fontconfig-mono"
        serifs = "slab"
        no-cv-ss = true
        export-glyph-names = true

          [buildPlans.iosevka-custom.ligations]
          inherits = "dlig"

        [buildPlans.iosevka-custom.weights.regular]
        shape = 400
        menu = 400
        css = 400

        [buildPlans.iosevka-custom.weights.bold]
        shape = 700
        menu = 700
        css = 700

        [buildPlans.iosevka-custom.weights.extrabold]
        shape = 800
        menu = 800
        css = 800

        [buildPlans.iosevka-custom.slopes.upright]
        angle = 0
        shape = "upright"
        menu = "upright"
        css = "normal"

        [buildPlans.iosevka-custom.slopes.italic]
        angle = 9.4
        shape = "italic"
        menu = "italic"
        css = "italic"
      '';
      set = "custom";
    };
  })
  (final: prev: {
    firefox-darwin = prev.stdenv.mkDerivation rec {
      pname = "Firefox";
      version = "119.0.1";

      buildInputs = [ prev.undmg ];
      sourceRoot = ".";
      phases = [ "unpackPhase" "installPhase" ];
      installPhase = ''
          mkdir -p "$out/Applications"
          cp -r Firefox.app "$out/Applications/Firefox.app"
        '';

      src = prev.fetchurl {
        name = "Firefox-${version}.dmg";
        url = "https://download-installer.cdn.mozilla.net/pub/firefox/releases/${version}/mac/en-GB/Firefox%20${version}.dmg";
        sha256 = "1pswrw5a552c5v8ls9xmclmwqprw52vparvaqp51j4il9rh5vrxa";
      };
    };
  })
  ]
