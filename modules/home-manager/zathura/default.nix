{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.zathura;

in {
  options.modules.zathura = { enable = mkEnableOption "zathura"; };
  config = mkIf cfg.enable {

    xdg.configFile."zathura/zathurarc".text = (builtins.concatStringsSep "\n" [

      (builtins.readFile (pkgs.fetchFromGitHub {
        owner = "catppuccin";
        repo = "zathura";
        rev = "d85d8750acd0b0247aa10e0653998180391110a4";
        hash = "sha256-5Vh2bVabuBluVCJm9vfdnjnk32CtsK7wGIWM5+XnacM=";
      } + /src/catppuccin-frappe))

      "set recolor"

    ]);

    home.packages = [ pkgs.zathura ];

  };
}
