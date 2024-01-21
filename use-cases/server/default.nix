{ platform, lib, config, ... }:

with lib;
let cfg = config.modules.server;

in optionalAttrs platform.isLinux {
  options.modules.server = {
    enable = mkEnableOption "server";
    username = mkOption { type = types.str; };
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable (mkMerge [

    {
      users.users.${cfg.username} = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
        ];
      };
    }

    {
      users.groups.multimedia.members = [ "${cfg.username}" ];
      users.groups.backup.members = [ "${cfg.username}" ];
    }

    {
      modules = {
        nginx.enable = true;
        jellyfin.enable = true;
        homer.enable = true;
        authelia.enable = true;
        deluge.enable = true;
        arr.enable = true;
        endlessh.enable = true;
        monitoring.enable = true;
        hledger.enable = false;
        duckdns.enable = true;
        paperless.enable = true;
        syncthing.enable = true;
      };
    }
  ]);
}

