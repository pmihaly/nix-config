{ pkgs, inputs, vars, ... }: {
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = import ../../overlays;
  documentation.enable = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";
    imports = [
      ../../modules/home-manager
      inputs.agenix.homeManagerModules.default
      ../../secrets/home-manager
    ];

    nixpkgs.overlays = import ../../overlays;

    modules = {
      vscode.enable = true;
      firefox.enable = true;
      nvim.enable = true;
      git.enable = true;
      shell = {
        enable = true;
        bookmarks = vars.bookmarks;
      };
      mpv.enable = true;
      lf = {
        enable = true;
        bookmarks = vars.bookmarks;
      };
      kitty.enable = true;
      newsboat.enable = true;
      neomutt.enable = true;
      zathura.enable = true;
      discord.enable = true;
    };

    home.packages = let
      work = with pkgs; [
        awscli
        git-lfs
        saml2aws
        openssl
        obsidian
        jwt-cli
        libossp_uuid # uuid from cli
        slack
      ];
    in work ++ (with pkgs; [
      keepassxc
      syncthing
      act # running github actions locally
      nix-tree # visualisation of nix derivations
      keepass-diff # diffing .kdbx files
      inputs.img2theme.packages."${pkgs.system}".default
      inputs.agenix.packages."${pkgs.system}".default
      inputs.deploy-rs.packages."${pkgs.system}".default
      yt-dlp
    ]);
  };

  homebrew = {
    enable = true;
    onActivation = {
      upgrade = true;
      cleanup = "zap";
    };
    casks = let work = [ "sequel-ace" "pycharm-ce" ];
    in work ++ [
      "aerial" # screensaver
      "raycast" # command+space
      "docker"
      "messenger"
      "signal"
      "google-chrome"
      "caffeine" # keep screen alive
      "utm" # virtual machines
      "balenaetcher"
      "linearmouse"
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

  services.nix-daemon.enable = true;

  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      interval = {
        Hour = 3;
        Minute = 15;
      };
      user = vars.username;
    };
  };

  users.users.${vars.username}.home = "/Users/mihaly.papp";

  system.stateVersion = 4;
}

