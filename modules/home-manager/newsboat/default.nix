{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.newsboat;
in
{
  options.modules.newsboat = {
    enable = mkEnableOption "newsboat";
  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [ ".local/share/newsboat" ];

    programs.newsboat = {
      enable = true;
      autoReload = true;
      browser =
        if pkgs.stdenv.isDarwin then
          "${pkgs.firefox-bin}/Applications/Firefox.app/Contents/MacOS/firefox"
        else
          getExe' pkgs.xdg-utils "xdg-open";
      urls = [
        { url = "https://www.daemonology.net/hn-daily/index.rss"; }
        { url = "https://social.notjustbikes.com/@notjustbikes.rss"; }
        { url = "https://kiszamolo.hu/feed"; }
        { url = "https://feeds.feedburner.com/ThePragmaticEngineer"; }
        { url = "https://programming.dev/feeds/c/linux.xml?sort=Active"; }
        { url = "https://programming.dev/feeds/c/nix.xml?sort=Active"; }
        { url = "https://old.reddit.com/r/escapehungary.rss"; }
        { url = "https://old.reddit.com/r/kiszamolo.rss"; }
        { url = "https://old.reddit.com/r/programminghungary.rss"; }
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
      '';
    };

    programs.zsh.shellAliases.nb = "newsboat";
  };
}
