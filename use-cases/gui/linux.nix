{ platform, lib, config, ... }:

with lib;
let cfg = config.modules.linux;

in optionalAttrs platform.isLinux {
  options.modules.linux = {
    enable = mkEnableOption "linux";
    username = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    home-manager.users.${cfg.username} = {
      imports = [ ../../modules/home-manager ];

      modules = { hyprland.enable = true; };
    };

    modules = { qemu.enable = true; };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      lowLatency = {
        enable = true;
        quantum = 64;
        rate = 48000;
      };
    };
  };
}

