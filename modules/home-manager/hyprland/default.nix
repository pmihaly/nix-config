{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.hyprland;

in {
  options.modules.hyprland = { enable = mkEnableOption "hyprland"; };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wl-clipboard # `wl-copy` and `wl-paste`
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      xwayland.enable = true;

      settings = {
        monitor = [
          "HDMI-A-1, 2560x1080, 0x0, 1"
          "DP-1, preferred, 2560x0, 1"
        ];
        "exec-once" = "${pkgs.swaybg}/bin/swaybg --image ~/.nix-config/wallpaper.png";
        env = "XCURSOR_SIZE,24";
        input = {
          kb_options = "caps:escape";

          follow_mouse = 1;

          touchpad = { natural_scroll = false; };

          sensitivity = 0;
          repeat_rate = 100;
          repeat_delay = 200;
          accel_profile = "flat";
        };

        general = {
          gaps_in = 10;
          gaps_out = 40;
          border_size = 0;

          layout = "dwindle";
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            new_optimizations = true;
          };

          drop_shadow = true;
          shadow_range = 40;
          shadow_render_power = 3;
          "col.shadow" = "rgba(1a1a1aee)";
        };

        animations = {
          enabled = true;

          animation = [
            "windows, 1, 0.7, default"
            "workspaces, 1, 0.7, default"
            "fade, 1, 0.7, default"
          ];
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        master = { new_is_master = true; };

        misc = { disable_hyprland_logo = true; };

        "$mainMod" = "SUPER";

        bind = [
          "$mainMod, T, exec, kitty"
          "$mainMod, Q, killactive,"
          "$mainMod, SPACE, exec, ${pkgs.wofi}/bin/wofi --show drun"
          "$mainMod, R, exec, hyprctl reload"
          "$mainMod, F, fullscreen"
          "$mainMod, W, exec, firefox"
          "$mainMod, A, exec, kitty alsamixer"

          "$mainMod, h, movefocus, l"
          "$mainMod, j, movefocus, d"
          "$mainMod, k, movefocus, u"
          "$mainMod, l, movefocus, r"

          "$mainMod SHIFT, h, movewindow, l"
          "$mainMod SHIFT, j, movewindow, d"
          "$mainMod SHIFT, k, movewindow, u"
          "$mainMod SHIFT, l, movewindow, r"

          "$mainMod, n, workspace, 1"
          "$mainMod, e, workspace, 2"
          "$mainMod, i, workspace, 3"
          "$mainMod, l, workspace, 4"
          "$mainMod, u, workspace, 5"
          "$mainMod, y, workspace, 6"

          "$mainMod CONTROL, n, movetoworkspace, 1"
          "$mainMod CONTROL, e, movetoworkspace, 2"
          "$mainMod CONTROL, i, movetoworkspace, 3"
          "$mainMod CONTROL, l, movetoworkspace, 4"
          "$mainMod CONTROL, u, movetoworkspace, 5"
          "$mainMod CONTROL, y, movetoworkspace, 6"

          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };

    gtk = {
      enable = true;
      theme = {
        package = pkgs.nordic;
        name = "Nordic";
      };
      iconTheme = {
        package = pkgs.nordzy-icon-theme;
        name = "Nordzy";
      };
    };
  };
}
