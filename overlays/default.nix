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
    # MIDI Learn button in the plugin UI: tweak a plugin parameter, then click
    # "Learn" to show its automation lane and start Generic MIDI binding for it
    # (libs/widgets BindingProxy). Right-click for a menu (show lane only,
    # forget/unmap this parameter, open the "Learned MIDI Mappings" dialog with
    # track/plugin/parameter + MIDI controller list); a status label reports the
    # learned controller. Requires the Generic MIDI control surface. Patch
    # applies to ardour 9.8 (refs/tags/9.8). See
    # overlays/ardour-midi-learn-button.patch.
    #
    # Two-point mapping range: the "Mappings" button (right of Learn) lists
    # every learned binding with two sliders per row — the parameter value the
    # MIDI controller produces at 0 and at 127 — plus its live formatted value.
    # The range defaults to the full sweep and is stored with the binding in
    # the session. See overlays/ardour-midi-map-range.patch.
    #
    # Build speed: link with mold (measured ~17min -> ~11min). ccache was
    # tried and removed: ardour's waf `--prefix` bakes the output store path
    # into every translation unit, so each patch iteration changes the prefix
    # and 99% of the cache misses no matter what.
    ardour = prev.ardour.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./ardour-midi-learn-button.patch
        ./ardour-midi-map-range.patch
      ];
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.mold ];
      env = (old.env or { }) // {
        # nixpkgs already passes LINKFLAGS="-lpthread"; waf forwards the env to
        # every C/C++ link via the g++ driver, and -fuse-ld=mold makes the
        # driver exec `mold` (on PATH via nativeBuildInputs).
        LINKFLAGS = (old.env.LINKFLAGS or "") + " -fuse-ld=mold";
      };
    });
  })
]
