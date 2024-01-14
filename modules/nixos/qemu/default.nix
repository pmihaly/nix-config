{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.qemu;

in {
  options.modules.qemu = { enable = mkEnableOption "qemu"; };
  config = mkIf cfg.enable {

    home-manager.users.${vars.username} = {
      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = [ "qemu:///system" ];
          uris = [ "qemu:///system" ];
        };
      };
    };

    users.users.${vars.username} = {
      extraGroups = [ "libvirtd" ];
    };

    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };

    programs.virt-manager.enable = true;

  };
}
