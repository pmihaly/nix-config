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
        gcc
        unzip
      ];
    in
    work ++ nvimDeps ++ (with pkgs; [
      keepassxc
      slack
      lazydocker
      git
      httpie
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
      moreutils # extend unix pipelining
      keepass-diff # diffing .kdbx files
      watch # run a command periodically
      gnumake
      iosevka-custom
      nerdfonts-fira-code
      lsof
      qrencode # str to qr code
      ripgrep # basically grep
      killall
      sd # more intuitive search and replace
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
      dn = "find ~/lensadev -maxdepth 1 -type d | fzf | xargs nvim";
      d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
      pn = "find ~/personaldev -maxdepth 1 -type d | fzf | xargs nvim";
      p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
      lg = "lazygit";
      ld = "lazydocker";
      ms = "pushd ~/.nix-config ; make switch-mac ; popd";
      mp = "pushd ~/.nix-config ; sudo make switch-pc ; popd";
      nr = "sudo nix-store --verify --check-contents --repair";
      ns = "nix search nixpkgs";
      ncg = "nix-collect-garbage --delete-old";
      nsh = "nix-shell -p";
      cn = "nvim ~/.nix-config";
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
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.kitty = {
    enable = true;
    theme = "Nord";
    settings = {
      font_size = 13;
      font_family = "Iosevka Custom Bold Extended";
      bold_font = "Iosevka Custom Extrabold Extended";
      italic_font = "Iosevka Custom Bold Extended Italic";
      bold_italic_font = "Iosevka Custom Extrabold Extended Italic";
      window_padding_width = "30 150";
      hide_window_decorations = "titlebar-only";
      macos_option_as_alt = true;
      cursor_blink_interval = 0;
      cursor_shape = "block";
      enable_audio_bell = false;
      confirm_os_window_close = 0;
      close_on_child_death = true;
    };
    extraConfig = ''
      modify_font underline_position 0.5
      modify_font underline_thickness 140%
    '';
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
    ];
    extraConfig = ''
      #show-read-feeds no
      auto-reload yes
      show-keymap-hint no
      show-title-bar no
      scrolloff 999

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
}
