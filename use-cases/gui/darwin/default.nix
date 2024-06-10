{
  pkgs,
  inputs,
  platform,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.darwin;
  aerospace = pkgs.stdenvNoCC.mkDerivation {
    name = "aerospace";
    src = inputs.aerospace-zip;
    unpackPhase = ''
      mkdir -p $out/Applications
      cp -r $src/AeroSpace.app $out/Applications

      mkdir -p $out/bin
      cp $src/bin/aerospace $out/bin
    '';
  };
in
optionalAttrs platform.isDarwin {
  options.modules.darwin = {
    enable = mkEnableOption "darwin";
    username = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    system.defaults = {
      NSGlobalDomain = {
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 10;
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowShouldDragOnGesture = true; # drag windows from anywhere with cmd+ctrl
        AppleFontSmoothing = 2;
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        "com.apple.keyboard.fnState" = true;
        AppleInterfaceStyle = "Dark";
        _HIHideMenuBar = false;
      };
      finder = {
        FXPreferredViewStyle = "clmv";
        ShowPathbar = true;
        QuitMenuItem = true;
        ShowStatusBar = true;
        CreateDesktop = false;
      };
      dock.autohide = true;
      dock.static-only = true;
      trackpad.Clicking = true;
      finder.FXEnableExtensionChangeWarning = false;
    };

    fonts = {
      fontDir.enable = true;
      fonts = [ ];
    };

    home-manager.users.${vars.username} = {
      imports = [ ../../../modules/home-manager ];
      home.packages = [ aerospace ];

      home.file.".config/aerospace/aerospace.toml".text = inputs.nix-std.lib.serde.toTOML {
        after-login-command = [ ];
        after-startup-command = [ ];
        start-at-login = true;
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;
        accordion-padding = 30;
        default-root-container-layout = "tiles";
        default-root-container-orientation = "auto";
        key-mapping.preset = "qwerty";

        gaps = {
          inner.horizontal = 0;
          inner.vertical = 0;
          outer.left = 0;
          outer.bottom = 0;
          outer.top = 0;
          outer.right = 0;
        };

        mode.service.binding = {
          esc = [
            "reload-config"
            "mode main"
          ];
        };

        workspace-to-monitor-force-assignment = {
          "u" = "main";
          "i" = "main";
          "o" = "main";
          "p" = "main";

          "j" = "main";
          "k" = "main";
          "l" = "main";
          "semicolon" = "main";
        };

        mode.main.binding =
          let
            workspaceBinds =
              trivial.pipe
                [
                  "j"
                  "k"
                  "l"
                  "semicolon"

                  "u"
                  "i"
                  "o"
                  "p"
                ]
                [
                  (builtins.map (workspace: {
                    name = workspace;
                    value = null;
                  }))
                  builtins.listToAttrs
                  (lib.concatMapAttrs (
                    workspace: _: {
                      "alt-${workspace}" = "workspace ${workspace}";
                      "alt-shift-${workspace}" = [
                        "move-node-to-workspace ${workspace}"
                        "workspace ${workspace}"
                      ];
                    }
                  ))
                ];
          in
          workspaceBinds
          // {
            "alt-enter" = "exec-and-forget ${pkgs.wezterm}/bin/wezterm";
            "alt-slash" = "mode service";

            "alt-n" = "focus left";
            "alt-shift-n" = "move left";
            "alt-m" = "focus right";
            "alt-shift-m" = "move right";

            "alt-left" = "focus left";
            "alt-down" = "focus down";
            "alt-up" = "focus up";
            "alt-right" = "focus right";
            "alt-shift-left" = "move left";
            "alt-shift-down" = "move down";
            "alt-shift-up" = "move up";
            "alt-shift-right" = "move right";

            "alt-shift-minus" = "resize smart -50";
            "alt-shift-equal" = "resize smart +50";
          };
      };

      xdg.configFile = {
        "karabiner/karabiner.json" = {
          source = ./karabiner.json;
        };
      };
    };

    homebrew.casks = [
      "aerial" # screensaver
      "raycast" # command+space
      "messenger"
      "signal"
      "google-chrome"
      "caffeine" # keep screen alive
      "utm" # virtual machines
      "balenaetcher"
      "linearmouse"
      "karabiner-elements"
    ];
  };
}
