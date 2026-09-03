{
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.styling;
in
{
  options.modules.styling = {
    enable = mkEnableOption "styling";
  };

  config = mkIf cfg.enable {
    # ── system-level theming (NixOS) ────────────────────────────────
    # Stylix's NixOS module auto-imports its Home Manager module into
    # every home-manager user (homeManagerIntegration), so the HM-side
    # targets are set in the home-manager block below.
    stylix = {
      enable = true;
      # Only style what we asked for; don't touch firefox/grub/qt/etc.
      autoEnable = false;
      # Nord — matches the niri focus-ring colors and the old kitty rice.
      # base16-schemes ships the canonical nord.yaml.
      base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
      polarity = "dark";

      fonts = {
        serif = {
          name = "Noto Serif";
          package = pkgs.noto-fonts;
        };
        sansSerif = {
          name = "Inter Variable";
          package = pkgs.inter;
        };
        monospace = {
          name = "JetBrains Mono";
          package = pkgs.jetbrains-mono;
        };
        emoji = {
          name = "Noto Color Emoji";
          package = pkgs.noto-fonts-color-emoji;
        };
        sizes = {
          applications = 11;
          desktop = 11;
          popups = 13;
          # kitty: the terminal-emulator module sets its own font_size
          # (settings.font_size is emitted after stylix's, so it wins);
          # this value is a consistent default for anything else that
          # consumes the theme's terminal size.
          terminal = 13;
        };
      };

      targets = {
        fontconfig.enable = true; # default font family per role
        font-packages.enable = true; # install the font packages system-wide
        gtk.enable = true; # dconf, needed for GTK settings
        console.enable = true; # Linux TTY palette (greetd/tuigreet, early boot)
      };
    };

    # ── home-manager-side targets ───────────────────────────────────
    home-manager.users.${vars.username} = {
      stylix.targets = {
        gtk.enable = true; # adw-gtk3 theme + base16 css + UI fonts
        kitty.enable = true; # terminal colors + monospace font
        rofi.enable = true; # rofi/rasi theme (drun, emoji, …)

        # browsers: fonts + reader mode + Firefox Color theme (the CSS-only
        # firefox-gnome-theme target is NOT enabled — the firefox module ships
        # its own userChrome.css, which would clash with it).
        firefox = {
          enable = true;
          profileNames = [ "misi" ];
          colorTheme.enable = true;
        };
        mpv.enable = true; # uosc + OSD/subtitle colors
        lazygit.enable = true;
        btop.enable = true;

        # keepassxc is a Qt app: themes all Qt (kvantum) toolkits.
        qt.enable = true;

        # GNOME apps (GTK-based): source highlighting + gnome-text-editor + eog.
        gnome-text-editor.enable = true;
        gtksourceview.enable = true;
        eog.enable = true;

        # NOTE: there is no `stylix.targets.discord` — stylix only exposes
        # nixcord/vencord/vesktop (modded Discord builds). The plain `pkgs.discord`
        # in modules/home-manager/discord can't be themed by stylix, so nothing
        # is enabled here. Switch modules/home-manager/discord to e.g. vesktop to
        # get a themed Discord.
        tmux.enable = true; # base16 tmux status bar
        fzf.enable = true; # replaces the hand-set colors in modules/home-manager/shell
      };

      # stylix's firefox colorTheme target writes profiles.misi.extensions.settings;
      # HM's firefox module requires an explicit acknowledgment for that option.
      programs.firefox.profiles.misi.extensions.settings."FirefoxColor@mozilla.com".force = true;

      # niri has no stylix target, so its focus-ring/shadow colors are wired to
      # the scheme palette inside modules/home-manager/niri instead.

      # Restore the Papirus icon theme used before "visual defaultism" removed it.
      # Papirus-Dark to match the nord dark polarity (previously it was the
      # catppuccin-papirus-folders recolor, which clashed with nord).
      stylix.icons = {
        enable = true;
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
      };
    };
  };
}
