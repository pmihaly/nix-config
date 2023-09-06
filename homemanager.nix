{ pkgs, ... }:
{
  home.stateVersion = "22.05";

  nixpkgs.overlays = import ./overlays;

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
      ];
      nvimDeps = with pkgs; [
        nodejs
        cargo
        gcc
        unzip
        python310
        python310Packages.setuptools # vimspector debugpy
      ];
    in
    work ++ nvimDeps ++ (with pkgs; [
      keepassxc
      slack
      lazydocker
      git
      # httpie
      curlie # httpie but with --curl
      syncthing
      tldr
      yq-go
      jq
      jiq # interactive jq
      wget
      scrub # delete files securely
      duf # prettier lsblk
      act # running github actions locally
      gum # pretty shell scripts
      massren # mass file rename
      discord
      nix-tree # visualisation of nix derivations
      fd # alternative to find
      tig # prettier git tree
      parallel # xargs but with multiprocessing
      keepass-diff # diffing .kdbx files
      watch # run a command periodically
      gnumake
      iosevka-custom
      nerdfonts-fira-code
      lsof # used by kbp alias - Lists open files and the corresponding processes
      qrencode # str to qr code
      ripgrep # basically grep
      killall
      sd # more intuitive search and replace
      zathura # pdf reader
      transmission
      du-dust # prettier du -sh
      choose # frendlier cut
      pup # jq for html
      nushellFull # structured data manipulation - replaces jq, jiq and yq
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
    tmux.enableShellIntegration = true;
  };

  home.sessionPath = [
    "/Users/$USER/.local/bin"
    "/home/$USER/.local/bin"
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
      U = "!dust";
      R = "!massren";
      m = "push :mkdirWithParent<space>";
      t = "push :touchWithParent<space>";
      "<enter>" = "open";
      A = "rename"; # at the very end
      c = "push A<c-u>"; # new rename
      I = "push A<c-a>"; # at the very beginning
      i = "push A<a-b><a-b><a-f>"; # before extention
      a = "push A<a-b>"; # after extention
      M = "mark-save";
    };
  };

  programs.zsh = {
    enable = true;
    initExtra =
      let iglooPrompt = builtins.concatStringsSep "\n" [
        "export IGLOO_ZSH_PROMPT_THEME_HIDE_TIME=true"
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
      in
      builtins.concatStringsSep "\n"
        [
          ''
            autoload -U promptinit; promptinit

            set -o vi

            zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

            autoload -z edit-command-line
            zle -N edit-command-line
            bindkey "^X" edit-command-line

            [ -f ~/.zshrc_work ] && . ~/.zshrc_work
          ''
          iglooPrompt
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

    syntaxHighlighting = {
      enable = true;
      styles = {
        main = "";
        brackets = "";
      };
    };
    enableAutosuggestions = true;
    autocd = true;
    history = {
      ignoreDups = true;
    };
    shellAliases = {
      ls = "exa -lah $([ -d .git ] && echo '--git')";
      cat = "bat";
      d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
      dn = "d && nvim";
      p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
      pn = "p && nvim";
      o = "cd ~/Sync/org";
      on = "o && (fd \"^.*\.org$\" | fzf | xargs nvim)";
      lg = "lazygit";
      ld = "lazydocker";
      ms = "pushd ~/.nix-config ; make switch-mac ; popd";
      mp = "pushd ~/.nix-config ; sudo make switch-pc ; popd";
      nr = "sudo nix-store --verify --check-contents --repair";
      ns = "nix search nixpkgs";
      ncg = "nix-collect-garbage --delete-old";
      nsh = "nix-shell -p";
      cn = "cd ~/.nix-config && nvim";
      c = "cd ~/.nix-config";
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
      revo = "function _f() { revolut.sh ~/Sync/finances.yaml | vipe --suffix yaml | envelopes > ~/Sync/finances.yaml }; _f";
      fin = "$EDITOR ~/Sync/finances.yaml";
      nb = "newsboat";
      qr = "qrencode -t ansiutf8";
      sr = "function _f() { fd --type file --exec sd \"$1\" \"$2\" }; _f";
      du = "dust";
      lsblk = "duf";
      http = "curlie";
      wttr = "http wttr.in/budapest";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.alacritty = {
    enable = true;
    settings = {
      colors = {
        primary = {
          background = "#2e3440";
          foreground = "#d8dee9";
          dim_foreground = "#a5abb6";
        };
        cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        vi_mode_cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        selection = {
          text = "CellForeground";
          background = "#4c566a";
        };
        search = {
          matches = {
            foreground = "CellBackground";
            background = "#88c0d0";
          };
          footer_bar = {
            background = "#434c5e";
            foreground = "#d8dee9";
          };
        };
        normal = {
          black = "#3b4252";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#88c0d0";
          white = "#e5e9f0";
        };
        bright = {
          black = "#4c566a";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#8fbcbb";
          white = "#eceff4";
        };
        dim = {
          black = "#373e4d";
          red = "#94545d";
          green = "#809575";
          yellow = "#b29e75";
          blue = "#68809a";
          magenta = "#8c738c";
          cyan = "#6d96a5";
          white = "#aeb3bb";
        };
      };
      font = {
        normal = {
          family = "Iosevka Custom";
          style = "Bold Extended";
        };
        bold = {
          family = "Iosevka Custom";
          style = "Extrabold Extended";
        };
        italic = {
          family = "Iosevka Custom";
          style = "Bold Extended Italic";
        };
        bold_italic = {
          family = "Iosevka Custom";
          style = "Extrabold Extended Italic";
        };
      };
      window = {
        padding = {
          x = 150;
          y = 0;
        };
        dynamic_padding = true;
        decorations = "none";
        startup_mode = "Fullscreen";
      };
      option_as_alt = "Both";
      shell = {
        program = "zsh";
        args = [ "-c" "tmux attach || zsh" ];
      };
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

  programs.newsboat = {
    enable = true;
    autoReload = true;
    urls = [
      { url = "https://www.daemonology.net/hn-daily/index.rss"; }
      { url = "https://nitter.net/GergelyOrosz/rss"; }
      { url = "https://feeds.feedburner.com/ThePragmaticEngineer"; }
      { url = "https://www.reddit.com/r/ExperiencedDevs/.rss"; }
      { url = "https://news.ycombinator.com/rss"; }
      { url = "https://programming.dev/feeds/local.xml?sort=Active"; }
      { url = "https://programming.dev/feeds/c/functional_programming.xml?sort=Active"; }
      { url = "https://programming.dev/feeds/c/linux.xml?sort=Active"; }
      { url = "https://programming.dev/feeds/c/experienced_devs.xml?sort=Active"; }
      { url = "https://programming.dev/feeds/c/nix.xml?sort=Active"; }
      { url = "https://programming.dev/feeds/c/commandline.xml?sort=Active"; }
      { url = "https://beehaw.org/feeds/c/technology.xml?sort=Active"; }
      { url = "https://lobste.rs/rss"; }
      { url = "https://kiszamolo.hu/feed"; }
    ];
    extraConfig = ''
      #show-read-feeds no
      auto-reload yes
      show-keymap-hint no
      show-title-bar no
      scrolloff 999
      reload-threads 100

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

  programs.vscode = {
    enable = true;
    enableExtensionUpdateCheck = false;
    enableUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
      arcticicestudio.nord-visual-studio-code
      eamodio.gitlens
      asvetliakov.vscode-neovim
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
    ];
    userSettings = {
      "workbench.colorTheme" = "Nord";
      "editor.cursorSmoothCaretAnimation" = "on";
      "editor.smoothScrolling" = true;
      "editor.minimap.enabled" = false;
      "editor.formatOnSave" = true;
      "files.autoSave" = "onFocusChange";
      "files.insertFinalNewline" = true;
      "files.trimTrailingWhitespace" = true;
      "explorer.autoReveal" = true;
      "workbench.editor.enablePreview" = false;
      "workbench.editor.tabCloseButton" = "right";
      "workbench.editor.tabSizing" = "shrink";
      "workbench.panel.defaultLocation" = "right";
      "workbench.settings.editor" = "json";
      "workbench.sideBar.location" = "right";
      "[javascript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
    };
  };

  programs.tmux = {
    enable = true;
    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.nord
      tmuxPlugins.fuzzback
      tmuxPlugins.fzf-tmux-url
      tmuxPlugins.resurrect
      tmuxPlugins.continuum
    ];
    mouse=true;
    clock24=true;
    extraConfig = ''
      set-option -g status-interval 5
      set-option -g automatic-rename on
      set-option -g automatic-rename-format '#{b:pane_current_path} #{pane_current_command}'
      set-option -g status off

      set-option -g prefix C-Space
      bind-key C-Space send-prefix

      bind j display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command}' | grep -v \"$(tmux display-message -p '#I') \" | fzf --with-nth=2,3 | choose 0 | xargs tmux select-window -t"

      set -g @fuzzback-bind ?
      set -g @fzf-url-bind u

      set -g @continuum-restore 'on'
    '';
  };
}
