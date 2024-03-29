{ platform, lib, config, ... }:

with lib;
let cfg = config.modules.darwin;

in optionalAttrs platform.isDarwin {
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
    ];
  };
}

