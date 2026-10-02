{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.niri;
  term = config.modules.terminal-emulator;
  wallpaper = ../../../wallpaper.png;
in
{
  options.modules.niri = {
    enable = mkEnableOption "niri";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wl-clipboard # `wl-copy` and `wl-paste`
      nemo
      imv # image viewer
      bibata-cursors # cursor theme (X11 format; niri uses it via the cursor section + XCURSOR_* env)
      xwayland-satellite # niri auto-starts this for X11 apps (it must be in $PATH)
      slurp # region selection for screenshots
      grim # screenshots
      swaybg # wallpapers (spawn-at-startup in the config below)
    ];

    home.pointerCursor = {
      enable = true;
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
    };

    services.gammastep = {
      enable = true;
      provider = "manual";
      latitude = 52.3728;
      longitude = 4.8936;
    };

    programs.rofi = {
      enable = true;
      plugins = with pkgs; [ rofi ];
      extraConfig = {
        show-icons = true;
        terminal = term.binary;
      };
    };

    xdg.configFile."niri/config.kdl".text = ''
      output "DP-2" {
          mode "2560x1440@144.006"
      }

      spawn-at-startup "swaybg" "--image" "${wallpaper}"

      environment {
          XCURSOR_THEME "Bibata-Modern-Classic"
          XCURSOR_SIZE "24"
      }

      cursor {
          xcursor-theme "Bibata-Modern-Classic"
          xcursor-size 24
      }

      input {
          // Don't take over the power button (niri would otherwise make it
          // suspend instead of power off). Let logind handle it: the machine
          // config sets services.logind.powerKey = "poweroff".
          disable-power-key-handling

          keyboard {
              xkb {
                  model "pc105"
                  layout "us"
              }
              repeat-rate 100
              repeat-delay 200
          }
          mouse {
              accel-profile "flat"
              accel-speed 0
          }
          focus-follows-mouse
      }

      layout {
          gaps 10
          struts {
              left 40
              right 40
              top 40
              bottom 40
          }
          default-column-width { proportion 0.5; }
          focus-ring {
              width 1
              active-color "#${config.lib.stylix.colors.base0D}"
              inactive-color "#${config.lib.stylix.colors.base01}"
          }
          shadow {
              on
              softness 30
              spread 0
              offset x=0 y=5
              color "#${config.lib.stylix.colors.base00}88"
	      draw-behind-window true
          }
      }

      prefer-no-csd

      hotkey-overlay {
          skip-at-startup
      }

      screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

      window-rule {
          geometry-corner-radius 20
          clip-to-geometry true
          background-effect {
              blur true
          }
      }

      workspace "w1" { open-on-output "DP-2"; }
      workspace "w2" { open-on-output "DP-2"; }
      workspace "w3" { open-on-output "DP-2"; }
      workspace "w4" { open-on-output "DP-2"; }
      workspace "w5" { open-on-output "DP-2"; }
      workspace "w6" { open-on-output "DP-2"; }
      workspace "w7" { open-on-output "DP-2"; }
      workspace "w8" { open-on-output "DP-2"; }
      workspace "w9" { open-on-output "DP-2"; }

      binds {
          Mod+Return hotkey-overlay-title="Open a Terminal" { spawn "${term.name-in-shell}"; }
          Mod+Q { close-window; }
          Mod+Space hotkey-overlay-title="Run an Application" { spawn "rofi" "-show" "drun"; }
          Mod+X { spawn "rofi" "-modi" "emoji" "-show" "emoji"; }
          Mod+R { switch-preset-column-width; }
          Mod+F { toggle-windowed-fullscreen; } // was `fullscreen`
          Mod+V { toggle-window-floating; }
          Mod+W hotkey-overlay-title="Open Firefox" { spawn "firefox"; }
          Mod+A { spawn "${term.new-window-with-commad}" "${pkgs.pulsemixer}/bin/pulsemixer"; }
          Mod+S hotkey-overlay-title="Screenshot a region" { spawn-sh "slurp | xargs -I{} ${pkgs.grim}/bin/grim -g {}"; }

          Mod+N { focus-column-left-or-last; }
          Mod+M { focus-column-right-or-first; }

          Mod+Ctrl+N { swap-window-right; }
          Mod+Ctrl+M { swap-window-left; }

          // keyd (machines/aesop/default.nix) maps the physical left Alt to Ctrl,
          // so the physical Alt+Shift+N/M arrives here as Ctrl+Shift+N/M.
          // Bind both: N moves the window left, M moves it right (like Mod+N/M focus).
          Alt+Shift+N  { swap-window-left; }
          Alt+Shift+M  { swap-window-right; }
          Ctrl+Shift+N { swap-window-left; }
          Ctrl+Shift+M { swap-window-right; }

          Mod+J { focus-workspace "w1"; }
          Mod+K { focus-workspace "w2"; }
          Mod+L { focus-workspace "w3"; }
          Mod+Semicolon { focus-workspace "w4"; }
          Mod+U { focus-workspace "w5"; }
          Mod+I { focus-workspace "w6"; }
          Mod+O { focus-workspace "w7"; }
          Mod+P { focus-workspace "w8"; }

          Mod+Ctrl+J { move-window-to-workspace "w1"; }
          Mod+Ctrl+K { move-window-to-workspace "w2"; }
          Mod+Ctrl+L { move-window-to-workspace "w3"; }
          Mod+Ctrl+Semicolon { move-window-to-workspace "w4"; }
          Mod+Ctrl+U { move-window-to-workspace "w5"; }
          Mod+Ctrl+I { move-window-to-workspace "w6"; }
          Mod+Ctrl+O { move-window-to-workspace "w7"; }
          Mod+Ctrl+P { move-window-to-workspace "w8"; }

          // Physical Alt+Shift+1..9 arrives as Ctrl+Shift+1..9 (keyd swap); bind both.
          Alt+Shift+1  { move-window-to-workspace "w1"; }
          Alt+Shift+2  { move-window-to-workspace "w2"; }
          Alt+Shift+3  { move-window-to-workspace "w3"; }
          Alt+Shift+4  { move-window-to-workspace "w4"; }
          Alt+Shift+5  { move-window-to-workspace "w5"; }
          Alt+Shift+6  { move-window-to-workspace "w6"; }
          Alt+Shift+7  { move-window-to-workspace "w7"; }
          Alt+Shift+8  { move-window-to-workspace "w8"; }
          Alt+Shift+9  { move-window-to-workspace "w9"; }
          Ctrl+Shift+1 { move-window-to-workspace "w1"; }
          Ctrl+Shift+2 { move-window-to-workspace "w2"; }
          Ctrl+Shift+3 { move-window-to-workspace "w3"; }
          Ctrl+Shift+4 { move-window-to-workspace "w4"; }
          Ctrl+Shift+5 { move-window-to-workspace "w5"; }
          Ctrl+Shift+6 { move-window-to-workspace "w6"; }
          Ctrl+Shift+7 { move-window-to-workspace "w7"; }
          Ctrl+Shift+8 { move-window-to-workspace "w8"; }
          Ctrl+Shift+9 { move-window-to-workspace "w9"; }

          XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"; }
          XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"; }

          Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
          Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

          Mod+Shift+Slash { show-hotkey-overlay; }

          Mod+Left  { focus-column-left; }
          Mod+Down  { focus-window-down; }
          Mod+Up    { focus-window-up; }
          Mod+Right { focus-column-right; }

          Mod+Ctrl+Left  { move-column-left; }
          Mod+Ctrl+Down  { move-window-down; }
          Mod+Ctrl+Up    { move-window-up; }
          Mod+Ctrl+Right { move-column-right; }

          Mod+Home { focus-column-first; }
          Mod+End  { focus-column-last; }
          Mod+Ctrl+Home { move-column-to-first; }
          Mod+Ctrl+End  { move-column-to-last; }

          Mod+BracketLeft  { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }
          Mod+Comma  { consume-window-into-column; }
          Mod+Period { expel-window-from-column; }

          Mod+C { center-column; }
          Mod+Ctrl+C { center-visible-columns; }
          Mod+Ctrl+F { expand-column-to-available-width; }

          Mod+Minus { set-column-width "-10%"; }
          Mod+Equal { set-column-width "+10%"; }
          Mod+Shift+Minus { set-window-height "-10%"; }
          Mod+Shift+Equal { set-window-height "+10%"; }

          Mod+Shift+V { switch-focus-between-floating-and-tiling; }
          Mod+Shift+W { toggle-column-tabbed-display; }
          Mod+Shift+F { fullscreen-window; }
          Mod+Shift+O { toggle-overview; }
          Mod+Shift+P { power-off-monitors; }

          Print { screenshot; }
          Ctrl+Print { screenshot-screen; }
          Alt+Print { screenshot-window; }

          Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
          Mod+Shift+E { quit; }
          Ctrl+Alt+Delete { quit; }
      }
    '';
  };
}
