{
  platform,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.linux;
in
optionalAttrs platform.isLinux {
  options.modules.linux = {
    enable = mkEnableOption "linux";
    username = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    home-manager.users.${vars.username} = {
      imports = [ ../../modules/home-manager ];

      modules = {
        hyprland.enable = true;
      };
    };

    modules = {
      qemu.enable = true;
      tailscale.enable = true;
    };

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

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${getExe pkgs.tuigreet} --time --remember --cmd Hyprland";
          user = "greeter";
        };
      };
    };

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    programs.ssh.startAgent = true;
  };
}
