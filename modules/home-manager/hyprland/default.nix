{
  pkgs,
  lib,
  config,
  inputs,
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
      inputs.hyprland-qtutils.packages."${pkgs.system}".default
      imv # image viewer
    ];

    services.gammastep = {
      enable = true;
      provider = "manual";
      latitude = 47.4979;
      longitude = 19.0402;
    };

    programs.rofi = {
      enable = true;
      plugins = with pkgs; [
        rofi
      ];
      extraConfig = {
        show-icons = true;
        terminal = config.modules.terminal-emulator.binary;
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      xwayland.enable = true;
      sourceFirst = true;

      settings = {
        ecosystem.no_update_news = true;
        monitor = [
          "DP-1, 2560x1440@144, 0x0, 1"
        ];
        "exec-once" = "${getExe pkgs.swaybg} --image ${../../../wallpaper.jpg}";
        env = [
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

        animations.enabled = false;

        general = {
          gaps_in = 0;
          gaps_out = 0;
          allow_tearing = 1;
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
          "1,monitor:DP-2"
          "2,monitor:DP-2"
          "3,monitor:DP-2"
          "4,monitor:DP-2"
          "5,monitor:DP-2"
          "6,monitor:DP-2"
          "7,monitor:DP-2"
          "8,monitor:DP-2"
          "9,monitor:DP-2"
        ];

        bind = [
          "$mainMod, T, exec, ${config.modules.terminal-emulator.name-in-shell}"
          "$mainMod, Q, killactive,"
          "$mainMod, SPACE, exec, rofi -show drun"
          "$mainMod, x, exec, rofi -modi emoji -show emoji"
          "$mainMod, R, exec, hyprctl reload"
          "$mainMod, F, fullscreen"
          "$mainMod, W, exec, firefox"
          "$mainMod, A, exec, ${config.modules.terminal-emulator.new-window-with-commad} ${getExe pkgs.pulsemixer}"

          "$mainMod, k, cyclenext"
          "$mainMod, h, cyclenext, prev"

          "$mainMod CONTROL, k, swapnext"
          "$mainMod CONTROL, h, swapnext, prev"

          "$mainMod, m, workspace, 1"
          "$mainMod, n, workspace, 2"
          "$mainMod, e, workspace, 3"
          "$mainMod, i, workspace, 4"
          "$mainMod, o, workspace, 5"
          "$mainMod, j, workspace, 6"
          "$mainMod, l, workspace, 7"
          "$mainMod, u, workspace, 8"
          "$mainMod, y, workspace, 9"

          "$mainMod CONTROL, m, movetoworkspace, 1"
          "$mainMod CONTROL, n, movetoworkspace, 2"
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
