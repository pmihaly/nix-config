{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.nvim;

in {
  options.modules.nvim = { enable = mkEnableOption "nvim"; };
  config = mkIf cfg.enable {

    modules.persistence.directories =
      [ ".local/share/nvim" ".config/github-copilot" ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withNodeJs = true;
    };

    xdg.configFile = {
      nvim = {
        source = ./nvim;
        recursive = true;
      };
    };

    home.packages = with pkgs; [
      nodejs
      cargo
      gcc
      unzip
      python310
      python310Packages.setuptools # vimspector debugpy
      go
    ];
  };
}
