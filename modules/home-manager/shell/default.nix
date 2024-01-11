{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.shell;

in {
  options.modules.shell = { enable = mkEnableOption "shell"; };
  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      git
      httpie
      # curlie # httpie but with --curl
      tldr
      yq-go
      jq
      jiq # interactive jq
      wget
      scrub # delete files securely
      gum # pretty shell scripts
      fd # alternative to find
      parallel # xargs but with multiprocessing
      watch # run a command periodically
      gnumake
      ripgrep # basically grep
      killall
      sd # more intuitive search and replace
      choose # frendlier cut
      pup # jq for html
      nushellFull # structured data manipulation - replaces jq, jiq and yq
      dog # dns client
    ];

    programs.bat = {
      enable = true;
      config = { theme = "catpuccin-frappe"; };
      themes = {
        catpuccin-frappe = {
          src = pkgs.fetchFromGitHub {
            owner = "catppuccin";
            repo = "bat";
            rev = "ba4d16880d63e656acced2b7d4e034e4a93f74b1";
            hash = "sha256-6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
          };
          file = "Catppuccin-frappe.tmTheme";
        };
      };
    };

    programs.fzf = {
      enable = true;
      tmux.enableShellIntegration = true;
      enableZshIntegration = true;
    };

    home.sessionPath = [
      "/Users/$USER/.local/bin"
      "/home/$USER/.local/bin"
      "/usr/local/bin"
      "/etc/profiles/per-user/$USER/bin"
      "/run/current-system/sw/bin/"
    ];

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
      settings = {
        palette = "catppuccin_frappe";
        add_newline = false;
        format = lib.concatStrings [ " " "$directory" "$character" ];
        scan_timeout = 10;
        directory = {
          truncation_length = 2;
          style = "bold fg:flamingo";
        };
        character = {
          success_symbol = "🔮(hidden)";
          error_symbol = "🔮(hidden)";
          vimcmd_symbol = "🔮(hidden)";
          vimcmd_replace_one_symbol = "🔮(hidden)";
          vimcmd_replace_symbol = "🔮(hidden)";
          vimcmd_visual_symbol = "🔮(hidden)";
        };
      } // builtins.fromTOML (builtins.readFile (pkgs.fetchFromGitHub {
        owner = "catppuccin";
        repo = "starship";
        rev = "5629d2356f62a9f2f8efad3ff37476c19969bd4f";
        hash = "sha256-nsRuxQFKbQkyEI4TXgvAjcroVdG+heKX5Pauq/4Ota0=";
      } + /palettes/frappe.toml));
    };

    programs.zsh = {
      enable = true;
      initExtra = ''
        autoload -U promptinit; promptinit

        set -o vi

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

        autoload -z edit-command-line
        zle -N edit-command-line
        bindkey "^X" edit-command-line

        [ -f ~/.zshrc_work ] && . ~/.zshrc_work

        function unlockpdf() {
          ${pkgs.pdftk}/bin/pdftk $2 input_pw $1 output "unlocked_$2"
        }
      '';
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
      history = { ignoreDups = true; };
      shellAliases = {
        ls = "${pkgs.eza}/bin/eza -lah --icons $([ -d .git ] && echo '--git')";
        cat = "bat";
        d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
        dn = "d && nvim";
        p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
        pn = "p && nvim";
        o = "cd ~/Sync/org";
        on = ''o && (fd "^.*.org$" | fzf | xargs nvim)'';
        ld = "lazydocker";
        ms = "darwin-rebuild switch --flake ~/.nix-config#mac";
        mp = "nixos-rebuild switch --flake ~/.nix-config#pc";
        nr = "sudo nix-store --verify --check-contents --repair";
        ns = "nix search nixpkgs";
        ncg = "sudo nix-collect-garbage --delete-old";
        nsh = "function _f() { nix-shell -p $* --run zsh }; _f";
        nshr =
          "function _f() { program=$1; shift; nix-shell -p $program --run $@ }; _f";
        nshrr =
          "function _f() { program=$1; shift; nix-shell -p $program --run $program }; _f";
        cn = "cd ~/.nix-config && nvim";
        c = "cd ~/.nix-config";
        thokr = "${pkgs.thokr}/bin/thokr --full-sentences 20";
        kbp = ''
          sudo touch /dev/null ; ${pkgs.lsof}/bin/lsof -iTCP -sTCP:LISTEN -n -P +c0 | awk 'NR>1{gsub(/.*:/,"",$9); print $9, $1, $2}' | fzf --multi --with-nth=1,2 --header='Select processes to be killed' | cut -d' ' -f3 | xargs kill -9'';
        kaf = "kubectl apply -f";
        kak = ''
          function _kak() { kubectl kustomize --enable-helm "$1" | kubectl apply -f -; }; _kak'';
        pis = ''
          function _pis() { kubectl kustomize --enable-helm "$1" | kubectl delete -f -; }; _pis'';
        urlencode = "${pkgs.jq}/bin/jq -sRr @uri";
        dselect =
          "docker ps --format '{{.ID}}	{{.Image}}' | fzf --with-nth 2 | cut -f1";
        dim = ''
          dselect | tee >(tr -d '
          ' | pbcopy)'';
        dl = "dselect | xargs docker logs -f";
        dex =
          ''container=$(dselect); docker exec -it "$container" "''${@:-bash}"'';
        ticket = ''git branch --show-current | grep -oE "[A-Z]+-[0-9]+"'';
        revo =
          "function _f() { revolut.sh ~/Sync/finances.yaml | vipe --suffix yaml | envelopes > ~/Sync/finances.yaml }; _f";
        fin = "$EDITOR ~/Sync/finances.yaml";
        qr = "${pkgs.qrencode}/bin/qrencode -t ansiutf8";
        sr = ''
          function _f() { fd --type file --exec ${pkgs.sd}/bin/sd "$1" "$2" }; _f'';
        du = "${pkgs.du-dust}/bin/dust";
        lsblk = "${pkgs.duf}/bin/duf";
        wttr = "${pkgs.httpie}/bin/http wttr.in/budapest";
        n = "nvim";
        sharedir = "${pkgs.python3}/bin/python3 -m http.server 9000";
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };

    programs.btop = {
      enable = true;
      settings = {
        theme_background = false;
        true_color = true;
        update_ms = 200;
      };
    };

    programs.tmux = {
      enable = true;
      plugins = with pkgs; [
        tmuxPlugins.sensible
        tmuxPlugins.fuzzback
        tmuxPlugins.fzf-tmux-url
      ];
      mouse = true;
      clock24 = true;
      extraConfig = ''
        set-option -g status-interval 5
        set-option -g automatic-rename on
        set-option -g automatic-rename-format '#{b:pane_current_path} #{pane_current_command}'
        set-option -g status off
        set-option -g default-command zsh

        set-option -g prefix C-Space
        bind-key C-Space send-prefix

        bind j display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command}' | grep -v \"$(tmux display-message -p '#I') \" | fzf | choose 0 | xargs tmux select-window -t"

        bind k display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command}' | fzf --multi | choose 0 | xargs -I{} tmux kill-window -t {}"

        set -g @fuzzback-bind ?
        set -g @fzf-url-bind u
      '';
    };
  };
}
