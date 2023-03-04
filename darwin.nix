{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  documentation.enable = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."mihaly.papp" = { pkgs, ... }: {
    home.stateVersion = "22.05";

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withNodeJs = true;
    };

    xdg.configFile = {
      nvim = {
        source = ./nvim;
        recursive = true;
      };
    };

    home.packages =
      let
        python310 = pkgs.python310.withPackages (p: with p; [
          keyring
        ]);
        work = with pkgs; [
          python310
          awscli
          git-lfs
          saml2aws
          openssl
          libmemcached
          memcached
          mysql
          openvpn
          obsidian
          pipenv
          gremlin-console
        ];
        nvimDeps = with pkgs; [
          nodejs
          cargo
          ripgrep
        ];
      in
      work ++ nvimDeps ++ (with pkgs; [
        keepassxc
        slack
        lazydocker
        lazygit
        git
        httpie
        gping
        syncthing
        bat
        tldr
        neofetch
        kubectl
        kube3d
        kubectx
        k9s
        yq
        jq
        jiq # interactive jq
        wget
        asciiquarium # useless
        cbonsai # useless
        scrub # delete files securely
        duf # prettier lsblk
        onefetch # neofetch for git repos
        act # running github actions locally
        thokr # writing speed
        gum # pretty shell scripts
        massren # mass file rename
        discord
      ]);

    programs.yt-dlp = {
      enable = true;
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    home.sessionPath = [
      "/Users/$USER/.local/bin"
      "/usr/local/bin"
      "/etc/profiles/per-user/$USER/bin"
      "/run/current-system/sw/bin/"
    ];

    programs.exa = {
      enable = true;
    };

    programs.mpv = {
      enable = true;
      config = {
        fullscreen = true;
        ytdl-format = "bestvideo+bestaudio/best";
        osc = false;
      };
      defaultProfiles = [ "gpu-hq" ];
      scripts = [
        pkgs.mpvScripts.sponsorblock
        pkgs.mpvScripts.thumbnail
      ];
      bindings = {
        "l" = "seek 5";
        "h" = "seek -5";
        "j" = "seek -60";
        "k" = "seek 60";

        "s" = "cycle sub";
        "a" = "cycle audio";

        "Alt+h" = "add chapter -1";
        "Alt+l" = "add chapter 1";
        "Ctrl+SPACE" = "add chapter 1";

        "Alt+j" = "add video-zoom -0.25";
        "Alt+k" = "add video-zoom 0.25";

        "Alt+J" = "add sub-pos -1";
        "Alt+K" = "add sub-pos +1";

        "Ctrl+h" = "multiply speed 1/1.1";
        "Ctrl+l" = "multiply speed 1.1";
        "Ctrl+H" = "set speed 1.0";
      };
    };

    programs.lf = {
      enable = true;
      settings = {
        scrolloff = 999;
        hidden = true;
        smartcase = true;
      };
      commands = {
        delete =
          ''
            ''${{
              clear; tput cup $(($(tput lines)/3)); tput bold
              set -f
              printf "%s\n\t" "$fx"
              printf "delete? [y/N] "
              read ans
              [ "$ans" = "y" ] && echo "$fx" | tr ' ' '\ ' | xargs -I{} rm -rf -- "{}"
            }}
          '';
        mkdirWithParent = '' $mkdir -p "$(echo $* | tr ' ' '\ ')" '';
        touchWithParent = '' $mkdir -p "$(dirname "$*")" && touch "$*" '';
        open = '' $$EDITOR $f '';
      };
      keybindings = {
        D = "delete";
        U = "!du -sh";
        R = "!massren";
        m = "push :mkdirWithParent<space>";
        t = "push :touchWithParent<space>";
        "<enter>" = "open";
        A = "rename"; # at the very end
        c = "push A<c-u>"; # new rename
        I = "push A<c-a>"; # at the very beginning
        i = "push A<a-b><a-b><a-f>"; # before extention
        a = "push A<a-b>"; # after extention
      };
    };

    programs.zsh = {
      enable = true;
      initExtra = ''
        autoload -U promptinit; promptinit
        prompt walters

        set -o vi

        zstyle ':completion:*:*:*:default' menu yes select search interactive # browseable, searchable completions

        hash kubectl 2>/dev/null && . <(kubectl completion zsh)
        hash k3d 2>/dev/null && . <(k3d completion zsh)

        complete -C 'aws_completer' aws

        [ -f .zshrc_work ] && . ~/.zshrc_work
      '';
      enableCompletion = true;
      completionInit = ''
        autoload bashcompinit && bashcompinit
        autoload -Uz compinit && compinit
      '';

      enableSyntaxHighlighting = true;
      autocd = true;
      history = {
        ignoreDups = true;
      };
      shellAliases = {
        ls = "exa -lah --git";
        cat = "bat";
        dn = "find ~/lensadev -maxdepth 1 -type d | fzf | xargs nvim";
        d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
        pn = "find ~/personaldev -maxdepth 1 -type d | fzf | xargs nvim";
        p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
        lg = "lazygit";
        ld = "lazydocker";
        ms = "pushd ~/.nix-config ; make switch-mac ; popd";
        cn = "nvim ~/.nix-config";
        c = "cd ~/.nix-config";
        ping = "gping";
        thokr = "thokr --full-sentences 20";
        kbp = "sudo touch /dev/null ; lsof -iTCP -sTCP:LISTEN -n -P +c0 | awk 'NR>1{gsub(/.*:/,\"\",$9); print $9, $1, $2}' | fzf --multi --with-nth=1,2 --header='Select processes to be killed' | cut -d' ' -f3 | xargs kill -9";
        kaf="kubectl apply -f";
        kak="function _kak() { kubectl kustomize --enable-helm \"$1\" | kubectl apply -f -; }; _kak";
        pis="function _pis() { kubectl kustomize --enable-helm \"$1\" | kubectl delete -f -; }; _pis";
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };

    programs.kitty = {
      enable = true;
      font = {
        name = "FiraCode Nerd Font Mono";
        size = 13;
      };
      theme = "Nord";
      settings = {
        window_padding_width = "30 100";
        hide_window_decorations = "titlebar-only";
        macos_option_as_alt = true;
        cursor_blink_interval = 0;
        enable_audio_bell = false;
      };
    };

    programs.btop = {
      enable = true;
      settings = {
        theme_background = false;
        true_color = true;
        update_ms = 200;
      };
    };
  };

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
      pkgs.nerdfonts
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

  system.stateVersion = 4;
}

