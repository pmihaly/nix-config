{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.hyprland;

in {
  options.modules.hyprland = { enable = mkEnableOption "hyprland"; };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      swaybg # setting wallpapers in wayland
      wofi # wayland equivalent of rofi
      wl-clipboard # `wl-copy` and `wl-paste`
    ];

    xdg.configFile = {
      hypr = {
        source = ./hypr;
        recursive = true;
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
