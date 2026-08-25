[
  # The generated python tree-sitter grammar bindings (pkgs/development/python-modules/
  # tree-sitter-grammars) set `pname = "python-tree-sitter-<lang>"` while the pyproject.toml
  # they generate declares `name = "tree_sitter_<lang>"`. pythonMetadataCheckHook looks up
  # the dist metadata by `pname`, so every one of them dies in pythonMetadataCheckPhase with
  # `PackageNotFoundError: No package metadata was found for python-tree-sitter-<lang>`.
  # This breaks anything depending on them (e.g. graphify). Drop when nixpkgs fixes the pname.
  (final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (pyFinal: pyPrev: {
        tree-sitter-grammars =
          pyPrev.tree-sitter-grammars
          // prev.lib.mapAttrs (_: drv: drv.overrideAttrs { dontCheckPythonMetadata = true; }) (
            prev.lib.filterAttrs (_: prev.lib.isDerivation) pyPrev.tree-sitter-grammars
          );
      })
    ];
  })

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
  })
]
