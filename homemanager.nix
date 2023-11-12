{ pkgs, customflakes, ... }:
{
  home.stateVersion = "22.05";

  nixpkgs.overlays = import ./overlays;

  imports = [ ./modules ];

  modules = {
    vscode.enable = true;
    firefox.enable = true;
    nvim.enable = true;
    lazygit.enable = true;
    zsh.enable = true;
    mpv.enable = true;
    lf.enable = true;
    kitty.enable = true;
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
    in
    work ++ (with pkgs; [
      keepassxc
      slack
      lazydocker
      syncthing
      act # running github actions locally
      massren # mass file rename
      discord
      nix-tree # visualisation of nix derivations
      tig # prettier git tree
      keepass-diff # diffing .kdbx files
      iosevka-custom
      nerdfonts-fira-code
      zathura # pdf reader
      transmission
      anki-bin
    ])
    ++ (with customflakes; [
      img2theme.packages."${pkgs.system}".default
    ]);

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

  programs.tmux = {
    enable = true;
    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.nord
      tmuxPlugins.fuzzback
      tmuxPlugins.fzf-tmux-url
    ];
    mouse=true;
    clock24=true;
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

}
