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
        pkgs.fzf
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

    programs.exa = {
      enable = true;
      enableAliases = true;
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
      "raycast"
      "docker"
      "messenger"
      "signal"
      "google-chrome"
    ];
  };

  environment.variables = {
    EDITOR = "nvim";
  };
  environment.systemPath = [ "~/.local/bin" ];
  environment.shellAliases = {
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

  programs.zsh = {
    enable = true;
    interactiveShellInit = "set -o vi";
    enableBashCompletion = true;
    enableFzfCompletion = true;
    enableFzfGit = true;
    enableFzfHistory = true; 
    enableSyntaxHighlighting = true; 
  };

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;
  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.defaults.NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
  system.defaults.NSGlobalDomain.AppleFontSmoothing = 2;
  system.defaults.NSGlobalDomain.AppleShowAllFiles = true;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.finder.FXPreferredViewStyle = "clmv";
  system.defaults.finder.ShowPathbar = true;
  system.defaults.finder.QuitMenuItem = true;
  system.defaults.finder.ShowStatusBar = true;
  system.defaults.dock.autohide = true;

  fonts = {
    fontDir.enable = true;
    fonts = [
      pkgs.fira-mono
    ];
  };

  services.nix-daemon.enable = true;

  system.stateVersion = 4;
}
