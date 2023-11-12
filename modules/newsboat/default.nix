{ lib, config, ... }:

with lib;
let cfg = config.modules.newsboat;

in {
  options.modules.newsboat = { enable = mkEnableOption "newsboat"; };
  config = mkIf cfg.enable {

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

    programs.zsh = {
      shellAliases = {
        nb = "newsboat";
      };
    };
  };
}
