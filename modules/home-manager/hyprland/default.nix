{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  options.modules.hyprland = {
    enable = mkEnableOption "hyprland";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wl-clipboard # `wl-copy` and `wl-paste`
      nemo
    ];

    services.gammastep = {
      enable = true;
      provider = "manual";
      latitude = 47.4979;
      longitude = 19.0402;
    };

    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;
      plugins = with pkgs; [
        rofi-emoji
        rofi-calc
      ];
      extraConfig = {
        icon-theme = "Papirus";
        show-icons = true;
        terminal = "wezterm";
        drun-display-format = "{icon} {name}";
        location = 0;
        disable-history = false;
        hide-scrollbar = true;
        display-drun = "   Apps ";
        display-run = "   Run ";
        display-window = "   Window";
        display-Network = " 󰤨  Network";
        sidebar-mode = true;
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      xwayland.enable = true;
      sourceFirst = true;

      settings = {
        monitor = [
          "DP-1, 2560x1440@144, 0x0, 1"
          "HDMI-A-1, 1920x1080, 2560x0, 1"
        ];
        "exec-once" = "${pkgs.swaybg}/bin/swaybg --image ~/.nix-config/wallpaper.png";
        env = [
          "XCURSOR_SIZE,24"
          "WLR_DRM_NO_ATOMIC,1"
        ];
        input = {
          kb_options = "caps:escape";

          follow_mouse = 1;

          touchpad = {
            natural_scroll = false;
          };

          sensitivity = 0;
          repeat_rate = 100;
          repeat_delay = 200;
          accel_profile = "flat";
        };

        general = {
          gaps_in = 10;
          gaps_out = 40;
          border_size = 0;
          # "col.active_border" = "$crust";
          # "col.inactive_border" = "$crust";
          allow_tearing = true;

          layout = "dwindle";
        };

        decoration = {
          rounding = 15;
          blur = {
            enabled = true;
            size = 10;
            passes = 3;
            new_optimizations = true;
          };

          shadow = {
            enabled = true;
            range = 80;
            render_power = 3;
          };
        };

        animations = {
          enabled = true;

          animation = [
            "windows, 1, 0.7, default"
            "workspaces, 1, 0.7, default"
            "fade, 1, 0.7, default"
            "border, 1, 0.7, default"
          ];
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        master = {
          new_status = true;
        };

        misc = {
          disable_hyprland_logo = true;
        };

        windowrulev2 = "immediate, class:^(.gamescope-wrapped|Minecraft*)$";

        "$mainMod" = "SUPER";

        workspace = [
          "1,monitor:DP-1"
          "2,monitor:DP-1"
          "3,monitor:DP-1"
          "4,monitor:DP-1"
          "5,monitor:DP-1"
          "6,monitor:HDMI-A-1"
          "7,monitor:HDMI-A-1"
          "8,monitor:HDMI-A-1"
          "9,monitor:HDMI-A-1"
        ];

        bind = [
          "$mainMod, T, exec, wezterm"
          "$mainMod, Q, killactive,"
          "$mainMod, SPACE, exec, rofi -show drun"
          "$mainMod, c, exec, rofi -show calc -modi calc -no-show-match -no-sort"
          "$mainMod, x, exec, rofi -modi emoji -show emoji"
          "$mainMod, R, exec, hyprctl reload"
          "$mainMod, F, fullscreen"
          "$mainMod, W, exec, firefox"
          "$mainMod, A, exec, wezterm ${pkgs.pulsemixer}/bin/pulsemixer"

          "$mainMod, h, movefocus, l"
          "$mainMod, j, movefocus, d"
          "$mainMod, k, movefocus, u"
          "$mainMod, l, movefocus, r"

          "$mainMod SHIFT, h, movewindow, l"
          "$mainMod SHIFT, j, movewindow, d"
          "$mainMod SHIFT, k, movewindow, u"
          "$mainMod SHIFT, l, movewindow, r"

          "$mainMod, m, workspace, 1"
          "$mainMod, n, workspace, 2"
          "$mainMod, e, workspace, 3"
          "$mainMod, i, workspace, 4"
          "$mainMod, o, workspace, 5"
          "$mainMod, j, workspace, 6"
          "$mainMod, l, workspace, 7"
          "$mainMod, u, workspace, 8"
          "$mainMod, y, workspace, 9"

          "$mainMod CONTROL, m, movetoworkspace, 2"
          "$mainMod CONTROL, n, movetoworkspace, 1" # first workspace is n
          "$mainMod CONTROL, e, movetoworkspace, 3"
          "$mainMod CONTROL, i, movetoworkspace, 4"
          "$mainMod CONTROL, o, movetoworkspace, 5"
          "$mainMod CONTROL, j, movetoworkspace, 6"
          "$mainMod CONTROL, l, movetoworkspace, 7"
          "$mainMod CONTROL, u, movetoworkspace, 8"
          "$mainMod CONTROL, y, movetoworkspace, 9"

          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"

          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };

  };
}
