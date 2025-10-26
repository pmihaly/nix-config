{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.nvim;
in
{
  options.modules.nvim = {
    enable = mkEnableOption "nvim";
  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [
      ".local/share/nvim"
      ".local/share/db-ui"
    ];
    programs.bash.sessionVariables.EDITOR = getExe config.programs.neovim.package;

    home.packages = [ pkgs.neovim ];
  };
}
