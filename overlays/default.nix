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
  (final: prev: {
    patool = prev.patool.overrideAttrs (_: {
      doInstallCheck = false;
    });

    python3Packages = prev.python3Packages.overrideScope (
      pyFinal: pyPrev: {
        patool = pyPrev.patool.overrideAttrs (_: {
          doInstallCheck = false;
        });
      }
    );

    python314Packages = prev.python314Packages.overrideScope (
      pyFinal: pyPrev: {
        patool = pyPrev.patool.overrideAttrs (_: {
          doInstallCheck = false;
        });
      }
    );
  })
  (final: prev: {
    # Custom MIDI mapping window in the plugin UI: the Learn button, the
    # two-point range slider, and the grouped Mappings dialog — one merged
    # net-delta patch against the ardour 9.8 source (refs/tags/9.8), generated
    # by diffing the pristine tree against the 4-patch development stack.
    # See overlays/ardour-midi-mapping.patch and the in-tree documentation in
    # use-cases/music-production/README.md.
    #
    # Learn shows the parameter's automation lane and starts a Generic MIDI
    # binding (libs/widgets BindingProxy); right-click for show lane only /
    # forget / mappings; a status label reports the learned controller. The
    # "Mappings" button opens a dialog grouping learned bindings by channel /
    # CC with collapsible groups (collapsed by default except the last-tweaked
    # group; group headings list the mapped parameters), per-parameter rows
    # carrying a two-handle range slider (value at MIDI 0 and MIDI 127),
    # Add last tweaked, Replace with last tweaked, and Remove, all through
    # session undo. Requires the Generic MIDI control surface.
    #
    # Build speed: link with mold (measured ~17min -> ~11min). ccache was
    # tried and removed: ardour's waf `--prefix` bakes the output store path
    # into every translation unit, so each patch iteration changes the prefix
    # and 99% of the cache misses no matter what.
    ardour = prev.ardour.overrideAttrs (
      old:
      {
        patches = (old.patches or [ ]) ++ [
          ./ardour-midi-mapping.patch
        ];
      }
      // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.mold ];
        env = (old.env or { }) // {
          # nixpkgs already passes LINKFLAGS="-lpthread"; waf forwards the env to
          # every C/C++ link via the g++ driver, and -fuse-ld=mold makes the
          # driver exec `mold` (on PATH via nativeBuildInputs).
          LINKFLAGS = (old.env.LINKFLAGS or "") + " -fuse-ld=mold";
        };
      }
    );
  })
]
