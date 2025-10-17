{
  pkgs,
  lib,
  config,
  inputs,
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
      files = [
        ".local/share/zsh"
      ];
      directories = [ ".local/share/direnv" ];
    };

    home.packages = with pkgs; [
      tldr
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
      dogdns # dns client
      yt-dlp
      inputs.nh.packages."${pkgs.system}".default
      (pkgs.writeScriptBin "is-up" ''
        #! ${getExe pkgs.nushell}
        def main [
          service: string # the service to check
        ]: nothing -> bool {
          ${getExe pkgs.tailscale} status --json
            | from json
            | get Peer
            | values
            | where {$service in $in.DNSName}
            | $in.0.Online
          }
      '')
    ];

    programs.starship.enableNushellIntegration = true;
    programs.yazi.enableNushellIntegration = true;
    programs.direnv.enableNushellIntegration = true;

    programs.bat.enable = true;

    programs.fzf = {
      enable = true;
      tmux.enableShellIntegration = false;
    };

    home.sessionPath = [
      "/Users/$USER/.local/bin"
      "/home/$USER/.local/bin"
      "/usr/local/bin"
      "/etc/profiles/per-user/$USER/bin"
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
          nu_indicator = "🧙";
          style = "bold fg:#b48ead";
        };
      };
    };

    programs.bash = {
      enable = true;
      shellAliases = {
        ns = cfg.rebuildSwitch;
      };
    };

    programs.zsh = {
      enable = true;
      dotDir = ".config/zsh";
      initContent = ''
        autoload -U promptinit; promptinit

        set -o vi

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

        autoload -z edit-command-line
        zle -N edit-command-line
        bindkey "^O" edit-command-line

        [ -f ~/.zshrc_work ] && . ~/.zshrc_work
      '';
      enableCompletion = true;
      completionInit = ''
        autoload bashcompinit && bashcompinit
        autoload -Uz compinit && compinit

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
      shellAliases = (bookmarksToAliases cfg.bookmarks);

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
    programs.fzf.enableZshIntegration = false;
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
        set-option -g default-command nu
        set-option -g terminal-overrides ",xterm-256color:Tc"

        set-option -g allow-passthrough on
        set-option -ga update-environment TERM
        set-option -ga update-environment TERM_PROGRAM

        set-option -g prefix C-Space
        bind-key C-Space send-prefix

        bind j display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command} #{pane_title}' | grep -v \"$(tmux display-message -p '#I') \" | fzf | choose 0 | xargs tmux select-window -t"

        bind k display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command} #{pane_title}' | fzf --multi | choose 0 | xargs -I{} tmux kill-window -t {}"

        set -g @fuzzback-bind ?
        set -g @fzf-url-bind u
      '';
    };
  };
}
