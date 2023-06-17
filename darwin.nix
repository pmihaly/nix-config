{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  documentation.enable = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."mihaly.papp" = import ./homemanager.nix;

  homebrew = {
    enable = true;
    onActivation = {
      upgrade = true;
      cleanup = "zap";
    };
    casks =
      let work = [
        "sequel-ace"
        "pycharm-ce"
        "insomnia"
      ];
      in
      work ++ [
        "sourcetree"
        "aerial"
        "raycast"
        "docker"
        "messenger"
        "signal"
        "google-chrome"
      ];
  };

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
    fonts = [
      (pkgs.nerdfonts.override {
        fonts = [ "FiraCode" ];
      })
      (pkgs.iosevka.override {
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

          [buildPlans.iosevka-custom.weights.medium]
          shape = 500
          menu = 500
          css = 500

          [buildPlans.iosevka-custom.weights.semibold]
          shape = 600
          menu = 600
          css = 600

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
      })
    ];
  };

  services.yabai = {
    enable = true;
    config = {
      focus_follows_mouse = "autoraise";
      mouse_follows_focus = "off";
      window_placement = "second_child";
      top_padding = 40;
      bottom_padding = 40;
      left_padding = 40;
      right_padding = 40;
      window_gap = 10;
      layout = "bsp";
      split_ratio = 0.55;
    };
    extraConfig = ''
      yabai -m rule --add label="Finder" app="^Finder$" title="(Co(py|nnect)|Move|Info|Pref)" manage=off
      yabai -m rule --add label="Safari" app="^Safari$" title="^(General|(Tab|Password|Website|Extension)s|AutoFill|Se(arch|curity)|Privacy|Advance)$" manage=off
      yabai -m rule --add label="macfeh" app="^macfeh$" manage=off
      yabai -m rule --add label="System Settings" app="^System Settings$" title=".*" manage=off
      yabai -m rule --add label="App Store" app="^App Store$" manage=off
      yabai -m rule --add label="Activity Monitor" app="^Activity Monitor$" manage=off
      yabai -m rule --add label="KeePassXC" app="^KeePassXC$" manage=off
      yabai -m rule --add label="Calculator" app="^Calculator$" manage=off
      yabai -m rule --add label="Dictionary" app="^Dictionary$" manage=off
      yabai -m rule --add label="mpv" app="^mpv$" manage=off
      yabai -m rule --add label="Software Update" title="Software Update" manage=off
      yabai -m rule --add label="About This Mac" app="System Information" title="About This Mac" manage=off
    '';
  };

  services.skhd = {
    enable = true;
    skhdConfig = "";
  };

  services.nix-daemon.enable = true;

  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      interval = { Hour = 3; Minute = 15; };
      user = "mihaly.papp";
    };
  };

  users.users."mihaly.papp".home = "/Users/mihaly.papp";

  system.stateVersion = 4;
}

