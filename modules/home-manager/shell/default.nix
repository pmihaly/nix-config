{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.shell;
  bookmarksToAliases = attrsets.mapAttrs' (
    name: value: attrsets.nameValuePair "g${name}" "cd ${value}"
  );
in
{
  options.modules.shell = {
    enable = mkEnableOption "shell";
    bookmarks = mkOption {
      default = { };
      type = types.attrs;
    };
    rebuildSwitch = mkOption { type = types.str; };
  };
  config = mkIf cfg.enable {

    modules.persistence = {
      files = [ ".local/share/zsh" ];
      directories = [ ".local/share/direnv" ];
    };

    home.packages = with pkgs; [
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
      ripgrep # basically grep
      killall
      sd # more intuitive search and replace
      choose # frendlier cut
      pup # jq for html
      dog # dns client
      gotify-cli
      nvd # nix version diff
    ];

    programs.nushell = {
      enable = true;
      shellAliases = (bookmarksToAliases cfg.bookmarks);
      extraConfig = ''
        plugin add ${getExe pkgs.nushellPlugins.polars}
        plugin use polars
      '';
    };
    programs.starship.enableNushellIntegration = false; # prompt from stylix
    programs.yazi.enableNushellIntegration = true;
    programs.direnv.enableNushellIntegration = true;

    programs.bat.enable = true;

    programs.fzf = {
      enable = true;
      tmux.enableShellIntegration = true;
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
      settings = {
        add_newline = false;
        format = lib.concatStrings [
          " "
          "$directory"
          "$shell"
        ];
        scan_timeout = 10;
        directory = {
          truncation_length = 2;
          style = "bold fg:#b48ead";
        };
        shell = {
          disabled = false;
          zsh_indicator = "🔮";
          nu_indicator = "🧮";
          style = "bold fg:#b48ead";
        };
      };
    };

    programs.zsh = {
      enable = true;
      dotDir = ".config/zsh";
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

        . <(${pkgs.kubectl}/bin/kubectl completion zsh)
        . <(${pkgs.k3d}/bin/k3d completion zsh)

        complete -C 'aws_completer' aws
      '';

      syntaxHighlighting = {
        enable = true;
        styles = {
          main = "";
          brackets = "";
        };
      };
      autosuggestion.enable = true;
      autocd = true;
      history = {
        path = "${config.xdg.dataHome}/zsh";
        ignoreDups = true;
      };
      shellAliases = (
        mkMerge [
          (bookmarksToAliases cfg.bookmarks)
          {
            ls = "${pkgs.eza}/bin/eza -lah --icons $([ -d .git ] && echo '--git')";
            cat = "bat";
            p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
            pn = "p && nvim";
            o = "cd ~/Sync/org";
            on = ''o && (fd "^.*.org$" | fzf | xargs nvim)'';
            ld = "${pkgs.lazydocker}/bin/lazydocker";
            nixprevdiff = "${getExe pkgs.nvd} diff /nix/var/nix/profiles/system-$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -n2 | head -n1 | ${getExe pkgs.choose} 0)-link /nix/var/nix/profiles/system";
            ns = cfg.rebuildSwitch + "; nixprevdiff";
            nr = "sudo nix-store --verify --check-contents --repair";
            ncg = "sudo nix-collect-garbage --delete-old";
            nsh = "function _f() { nix-shell -p $* --run zsh }; _f";
            ndiff = "nix profile diff-closures --profile /nix/var/nix/profiles/system";
            cn = "cd ~/.nix-config && nvim";
            c = "cd ~/.nix-config";
            thokr = "${pkgs.thokr}/bin/thokr --full-sentences 20";
            kbp = ''sudo touch /dev/null ; ${pkgs.lsof}/bin/lsof -iTCP -sTCP:LISTEN -n -P +c0 | awk 'NR>1{gsub(/.*:/,"",$9); print $9, $1, $2}' | fzf --multi --with-nth=1,2 --header='Select processes to be killed' | cut -d' ' -f3 | xargs kill -9'';
            kaf = "${pkgs.kubectl}/bin/kubectl apply -f";
            kak = ''function _kak() { ${pkgs.kubectl}/bin/kubectl kustomize --enable-helm "$1" | ${pkgs.kubectl}/bin/kubectl apply -f -; }; _kak'';
            pis = ''function _pis() { ${pkgs.kubectl}/bin/kubectl kustomize --enable-helm "$1" | ${pkgs.kubectl}/bin/kubectl delete -f -; }; _pis'';
            urlencode = "${pkgs.jq}/bin/jq -sRr @uri";
            dselect = "docker ps --format '{{.ID}}	{{.Image}}' | fzf --with-nth 2 | cut -f1";
            dim = ''
              dselect | tee >(tr -d '
              ' | pbcopy)'';
            dl = "dselect | xargs docker logs -f";
            dex = ''container=$(dselect); docker exec -it "$container" "''${@:-bash}"'';
            ticket = ''git branch --show-current | grep -oE "[A-Z]+-[0-9]+" | tr -d "\n"'';
            gut = "git";
            qr = "${pkgs.qrencode}/bin/qrencode -t ansiutf8";
            sr = ''function _f() { fd --type file --exec ${pkgs.sd}/bin/sd "$1" "$2" }; _f'';
            du = "${pkgs.du-dust}/bin/dust";
            lsblk = "${pkgs.duf}/bin/duf";
            wttr = "${pkgs.httpie}/bin/http wttr.in/budapest";
            n = "nvim";
            sharedir = "${pkgs.python3}/bin/python3 -m http.server 9000";
            yt-dlp = "nix run nixpkgs#yt-dlp --"; # always use the latest yt-dlp to mitigate 403 errors from youtube
            ncdu = "${getExe pkgs.ncdu} --color=dark -t8"; # ncurses disk usage (with colors and 8 threads)
            jd = "${pkgs.nodePackages_latest.json-diff}/bin/json-diff";
            }
        ]
      );

      localVariables = {
        XDG_DATA_HOME = config.xdg.dataHome;
        XDG_CONFIG_HOME = config.xdg.configHome;
        XDG_STATE_HOME = config.xdg.stateHome;
        XDG_CACHE_HOME = config.xdg.cacheHome;

        MANPAGER = "nvim +Man!";
        AWS_CONFIG_FILE = "${config.xdg.configHome}/aws/config";
        AWS_SHARED_CREDENTIALS_FILE = "${config.xdg.configHome}/aws/credentials";
        CARGO_HOME = "${config.xdg.dataHome}/cargo";
        DOCKER_CONFIG = "${config.xdg.configHome}/docker";
        GNUPGHOME = "${config.xdg.dataHome}/gnupg";
        GOPATH = "${config.xdg.dataHome}/go";
        GRADLE_USER_HOME = "${config.xdg.dataHome}/gradle";
        GTK2_RC_FILES = "${config.xdg.configHome}/gtk-2.0/gtkrc";
        IPYTHONDIR = "${config.xdg.configHome}/ipython";
        JUPYTER_CONFIG_DIR = "${config.xdg.configHome}/jupyter";
        LEDGER_FILE = "${config.xdg.dataHome}/hledger.journal";
        LESSHISTFILE = "${config.xdg.cacheHome}/less/history";
        NODE_REPL_HISTORY = "${config.xdg.dataHome}/node_repl_history";
        NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
        PARALLEL_HOME = "${config.xdg.configHome}/parallel";
        PYLINTHOME = "${config.xdg.cacheHome}/pylint";
        PYTHONSTARTUP = "${config.xdg.configHome}/python/pythonrc";
        REDISCLI_HISTFILE = "${config.xdg.dataHome}/redis/rediscli_history";
        STACK_ROOT = "${config.xdg.dataHome}/stack";
        WINEPREFIX = "${config.xdg.dataHome}/wine";
        XCOMPOSECACHE = "${config.xdg.cacheHome}/X11/xcompose";
        ZDOTDIR = "${config.home.homeDirectory}/.config/zsh";
        _JAVA_OPTIONS = ''-Djava.util.prefs.userRoot="${config.xdg.configHome}"/java'';
      };
    };
    programs.yazi.enableZshIntegration = true;
    programs.fzf.enableZshIntegration = true;
    programs.direnv.enableZshIntegration = true;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.btop = {
      enable = true;
      settings = {
        theme_background = false;
        true_color = true;
        update_ms = 100;
        vim_keys = true;
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
        set-option -g terminal-overrides ",xterm-256color:Tc"

        set-option -g allow-passthrough on
        set-option -ga update-environment TERM
        set-option -ga update-environment TERM_PROGRAM

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
