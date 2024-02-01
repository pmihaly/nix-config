{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.keepassxc;

in {
  options.modules.keepassxc = { enable = mkEnableOption "keepassxc"; };
  config = mkIf cfg.enable {

    home.packages = [ pkgs.keepassxc ];

    home.file.".config/keepassxc/keepassxc.ini".text = (generators.toINI { } {
      General.ConfigVersion = 2;
      Browser.CustomProxyLocation = "";
      GUI.TrayIconAppearance = "monochrome-light";
      SSHAgent.Enabled = true;
    });

  };
}
