[
  (final: prev: {
    nerdfonts-fira-code = prev.nerdfonts.override { fonts = [ "FiraCode" ]; };
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

        [buildPlans.iosevka-custom.weights.heavy]
        shape = 900
        menu = 900
        css = 900

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
]
