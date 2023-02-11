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
      extraConfig = builtins.concatStringsSep "\n" [
        ''
        luafile ${builtins.toString ./nvim/init.lua}
        ''
      ];
    };

    xdg.configFile = {
      nvim = {
        source = ./nvim;
        recursive = true;
      };
    };

    home.packages =
    let python310 = pkgs.python310.withPackages (p: with p; [
      keyring
    ]);
    work = [
        python310
        pkgs.awscli
        pkgs.git-lfs
        pkgs.saml2aws
        pkgs.openssl
        pkgs.libmemcached
        pkgs.memcached
        pkgs.mysql
        pkgs.openvpn
        pkgs.obsidian
        pkgs.pipenv
        pkgs.gremlin-console
      ];
    nvimDeps = [
        pkgs.nodejs
        pkgs.cargo
        pkgs.ripgrep
    ];
    in
      work ++ nvimDeps ++
      [ pkgs.keepassxc
        pkgs.slack
        pkgs.iterm2
        pkgs.lazydocker
        pkgs.lazygit
        pkgs.git
        pkgs.httpie
        pkgs.gping
        pkgs.syncthing
        pkgs.bat
        pkgs.tldr
        pkgs.btop
        pkgs.neofetch
        pkgs.kubectl
        pkgs.kube3d
        pkgs.kubectx
        pkgs.k9s
        pkgs.yq
        pkgs.jq
        pkgs.stack
      ];

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    home.sessionPath = [ "~/.local/bin" "/etc/profiles/per-user/$USER/bin" "/run/current-system/sw/bin/" ];

    programs.exa = {
      enable = true;
    };

    programs.mpv = {
      enable = true;
      config = {
        fullscreen = true;
        ytdl-format = "bestvideo[height<=?1080][vcodec!=?vp9]+bestaudio/best";
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
        m = "push :mkdirWithParent<space>";
        t = "push :touchWithParent<space>";
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

        source ~/.zshrc_work
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
        ls = "exa -lah";
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
      ];
    in
    work ++ [
      "amethyst"
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
    NSGlobalDomain.AppleKeyboardUIMode = 3;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;
    NSGlobalDomain.InitialKeyRepeat = 10;
    NSGlobalDomain.KeyRepeat = 1;
    NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
    NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
    NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
    NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
    NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
    NSGlobalDomain.AppleFontSmoothing = 2;
    NSGlobalDomain.AppleShowAllFiles = true;
    NSGlobalDomain.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv";
    finder.ShowPathbar = true;
    finder.QuitMenuItem = true;
    finder.ShowStatusBar = true;
    dock.autohide = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    trackpad.Clicking = true;
    finder.FXEnableExtensionChangeWarning = false;
  };

  fonts = {
    fontDir.enable = true;
    fonts = [
      pkgs.nerdfonts
    ];
  };

  services.nix-daemon.enable = true;

  system.stateVersion = 4;
}

