{
  pkgs,
  platform,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.darwin;
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

    services.tailscale = {
      enable = true;
    };

    networking.dns = [
      "100.100.100.100" # tailscale dns
      "8.8.8.8"
      "8.8.4.4"
    ];

    networking.knownNetworkServices = [
      "LG Monitor Controls 2"
      "LG Monitor Controls"
      "USB Controls"
      "AX88179A"
      "Wi-Fi"
      "Thunderbolt Bridge"
    ];

    home-manager.users.${vars.username} = {
      imports = [ ../../../modules/home-manager ];

      xdg.configFile = {
        "karabiner/karabiner.json" = {
          source = ./karabiner.json;
        };
      };
    };

    services.aerospace = {
      enable = true;
      settings = {
        after-login-command = [ ];
        after-startup-command = [ ];
        on-focus-changed = [ "move-mouse window-lazy-center" ];
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;
        accordion-padding = 30;
        default-root-container-layout = "tiles";
        default-root-container-orientation = "auto";
        key-mapping.preset = "qwerty";

        gaps = {
          inner.horizontal = 10;
          inner.vertical = 10;
          outer.left = 40;
          outer.bottom = 40;
          outer.top = 40;
          outer.right = 40;
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
          "p" = "secondary";

          "j" = "main";
          "k" = "main";
          "l" = "main";
          "semicolon" = "main";
        };

        mode.main.binding =
          let
            workspaceBinds =
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
              |> (builtins.map (workspace: {
                name = workspace;
                value = null;
              }))
              |> builtins.listToAttrs
              |> (lib.concatMapAttrs (
                workspace: _: {
                  "alt-${workspace}" = "workspace ${workspace}";
                  "alt-shift-${workspace}" = [
                    "move-node-to-workspace ${workspace}"
                    "workspace ${workspace}"
                  ];
                }
              ));
          in
          workspaceBinds
          // {
            "alt-enter" = "exec-and-forget ${
              config.home-manager.users.${vars.username}.modules.terminal-emulator.binary
            }";
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
    };

    homebrew.casks = [
      "aerial" # screensaver
      "raycast" # command+space
      "messenger"
      "caffeine" # keep screen alive
      "utm" # virtual machines
      "balenaetcher"
      "linearmouse"
      "karabiner-elements"
    ];
  };
}
