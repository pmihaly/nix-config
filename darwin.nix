{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  documentation.enable = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."mihaly.papp" = { pkgs, ... }:
    let darkMode = true; in
    {
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
          work = with pkgs; [
            awscli
            git-lfs
            saml2aws
            openssl
            obsidian
            jwt-cli
            libossp_uuid # uuid from cli
            (vscode-with-extensions.override
              {
                vscodeExtensions = with vscode-extensions; [
                  arcticicestudio.nord-visual-studio-code
                  eamodio.gitlens
                ];
              })
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
          git
          httpie
          gping
          syncthing
          tldr
          neofetch
          yq-go
          jq
          jiq # interactive jq
          wget
          scrub # delete files securely
          duf # prettier lsblk
          onefetch # neofetch for git repos
          act # running github actions locally
          thokr # writing speed
          gum # pretty shell scripts
          massren # mass file rename
          discord
          nix-tree # visualisation of nix derivations
          shellcheck
          shfmt
          fd # alternative to find
          tig # prettier git tree
        ]);


      programs.lazygit = {
        enable = true;
        settings = {
          services = {
            "gsh.lensa.com" = "gitlab:gitlab.lensa.com";
          };
          notARepository = "quit";

          customCommands = [
            {
              key = "b";
              command = "tig blame -- {{.SelectedFile.Name}}";
              context = "files";
              description = "blame file at tree";
              subprocess = true;
            }
            {
              key = "b";
              command = "tig blame -- {{.SelectedSubCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
              context = "commitFiles";
              description = "blame file at revision";
              subprocess = true;
            }
            {
              key = "B";
              command = "tig blame -- {{.SelectedCommitFile.Name}}";
              context = "commitFiles";
              description = "blame file at tree";
              subprocess = true;
            }
            {
              key = "t";
              command = "tig {{.SelectedSubCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
              context = "commitFiles";
              description = "tig file (history of commits affecting file)";
              subprocess = true;
            }
            {
              key = "t";
              command = "tig -- {{.SelectedFile.Name}}";
              context = "files";
              description = "tig file (history of commits affecting file)";
              subprocess = true;
            }
          ];
        };
      };

      programs.bat = {
        enable = true;
        config = {
          theme = "Nord";
        };
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
        initExtra = builtins.concatStringsSep "\n"
          [
            ''
              autoload -U promptinit; promptinit
              # prompt walters

              set -o vi

              # zstyle ':completion:*:*:*:default' menu yes select search interactive # browseable, searchable completions
              zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

              autoload -z edit-command-line
              zle -N edit-command-line
              bindkey "^X" edit-command-line

              export IGLOO_ZSH_PROMPT_THEME_HIDE_TIME=true

              [ -f ~/.zshrc_work ] && . ~/.zshrc_work
            ''
            (builtins.readFile
              (builtins.fetchurl
                {
                  url = "https://raw.githubusercontent.com/git/git/4ca12e10e6fbda68adcb32e78497dc261e94734d/contrib/completion/git-prompt.sh";
                  sha256 = "0rjwxf1vfkynjqns6drhbrfv7358zyhhx5j4zgawm25qwza4xggi";
                }))
            (builtins.readFile
              (builtins.fetchurl
                {
                  url = "https://raw.githubusercontent.com/arcticicestudio/igloo/18b735009f2baa29e3bbe1323a1fc2082f88b393/snowblocks/zsh/lib/themes/igloo.zsh";
                  sha256 = "17ln78ww66mg1k2yljpap74rf6fjjiw818x4pc2d5l6yjqgv8wfl";
                }))
          ];
        enableCompletion = true;
        completionInit = ''
          autoload bashcompinit && bashcompinit
          autoload -Uz compinit && compinit

          hash kubectl 2>/dev/null && . <(kubectl completion zsh)
          hash k3d 2>/dev/null && . <(k3d completion zsh)
          hash yq 2>/dev/null && . <(yq shell-completion zsh)

          complete -C 'aws_completer' aws
        '';

        enableSyntaxHighlighting = true;
        autocd = true;
        history = {
          ignoreDups = true;
        };
        shellAliases = {
          ls = "exa -lah $([ -d .git ] && echo '--git')";
          cat = "bat";
          dn = "find ~/lensadev -maxdepth 1 -type d | fzf | xargs nvim";
          d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
          pn = "find ~/personaldev -maxdepth 1 -type d | fzf | xargs nvim";
          p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
          lg = "lazygit";
          ld = "lazydocker";
          ms = "pushd ~/.nix-config ; make switch-mac ; popd";
          nix-repair = "sudo nix-store --verify --check-contents --repair";
          cn = "nvim ~/.nix-config";
          c = "cd ~/.nix-config";
          ping = "gping";
          thokr = "thokr --full-sentences 20";
          kbp = "sudo touch /dev/null ; lsof -iTCP -sTCP:LISTEN -n -P +c0 | awk 'NR>1{gsub(/.*:/,\"\",$9); print $9, $1, $2}' | fzf --multi --with-nth=1,2 --header='Select processes to be killed' | cut -d' ' -f3 | xargs kill -9";
          kaf = "kubectl apply -f";
          kak = "function _kak() { kubectl kustomize --enable-helm \"$1\" | kubectl apply -f -; }; _kak";
          pis = "function _pis() { kubectl kustomize --enable-helm \"$1\" | kubectl delete -f -; }; _pis";
          urlencode = "jq -sRr @uri";
          dselect = "docker ps --format '{{.ID}}\t{{.Image}}' | fzf --with-nth 2 | cut -f1";
          dim = "dselect | tee >(tr -d '\n' | pbcopy)";
          dl = "dselect | xargs docker logs -f";
          dex = "container=$(dselect); docker exec -it \"\$container\" \"\${@:-bash}\"";
          ticket = "git branch --show-current | grep -oE \"[A-Z]+-[0-9]+\"";
          revo = "function _f() { TMP=$(mktemp) ; revolut.sh ~/Sync/finances.yaml <$1 > $TMP && $EDITOR $TMP && envelopes <$TMP > ~/Sync/finances.yaml && rm -f $TMP }; _f";
          fin = "$EDITOR ~/Sync/finances.yaml";
          nb = "newsboat";
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
          name = "Iosevka Custom Medium Extended";
          size = 13;
        };
        theme = if darkMode then "Nord" else null;
        settings = {
          window_padding_width = "30 150";
          hide_window_decorations = "titlebar-only";
          macos_option_as_alt = true;
          cursor_blink_interval = 0;
          cursor_shape = "block";
          enable_audio_bell = false;
          confirm_os_window_close = 0;
          close_on_child_death = true;
        };
        extraConfig = builtins.concatStringsSep "\n"
          [
            ''
              modify_font underline_position 0.5
              modify_font underline_thickness 130%
            ''

            (if darkMode then
              "" else
              builtins.readFile (builtins.fetchurl { url = "https://raw.githubusercontent.com/mtyn/polar/20d9540e88c91b6f5f2b1010770877674fc1ece1/polar/kitty-terminal/polar.conf"; sha256 = "1qmlrcjdmp2fh5kw6xjnr8vm48ph12l6977hhp488p2lc5mx5aar"; })
            )
          ];
      };

      programs.btop = {
        enable = true;
        settings = {
          theme_background = false;
          true_color = true;
          update_ms = 200;
        };
      };

      programs.newsboat = {
        enable = true;
        autoReload = true;
        urls = [
          { url = "http://www.daemonology.net/hn-daily/index.rss"; }
          { url = "https://nitter.net/GergelyOrosz/rss"; }
          { url = "http://feeds.feedburner.com/ThePragmaticEngineer"; }
          { url = "https://www.reddit.com/r/ExperiencedDevs/.rss"; }
        ];
        extraConfig = ''
          #show-read-feeds no
          auto-reload yes
          show-keymap-hint no
          show-title-bar no

          bind-key j down
          bind-key k up
          bind-key j next articlelist
          bind-key k prev articlelist
          bind-key J next-feed articlelist
          bind-key K prev-feed articlelist
          bind-key G end
          bind-key g home
          bind-key d pagedown
          bind-key u pageup
          bind-key l open
          bind-key h quit
          bind-key a toggle-article-read
          bind-key n next-unread
          bind-key N prev-unread
          bind-key D pb-download
          bind-key U show-urls
          bind-key x pb-delete

          macro , open-in-browser

          color listnormal cyan default
          color listfocus black yellow standout bold
          color listnormal_unread blue default
          color listfocus_unread yellow default bold
          color info red black bold
          color article cyan default

          highlight article "^(Feed|Link):.*$" color6 default bold
          highlight article "^(Title|Date|Author):.*$" color6 default bold
          highlight article "https?://[^ ]+" color10 default underline
          highlight article "\\[[0-9]+\\]" color10 default bold
          highlight article "\\[image\\ [0-9]+\\]" color10 default bold
          highlight feedlist "^─.*$" color6 color236 bold
        '';
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
      _HIHideMenuBar = true;
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

