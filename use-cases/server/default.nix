{
  platform,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.server;
in
optionalAttrs platform.isLinux {
  options.modules.server = {
    enable = mkEnableOption "server";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable (mkMerge [

    {
      users.users.${vars.username} = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
        ];
      };
    }

    {
      users.groups.multimedia.members = [ "${vars.username}" ];
      users.groups.backup.members = [ "${vars.username}" ];
    }

    {
      modules = {
        nginx.enable = true;
        jellyfin.enable = true;
        homer.enable = true;
        deluge.enable = true;
        arr.enable = true;
        endlessh.enable = true;
        monitoring.enable = false;
        hledger.enable = false;
        paperless.enable = true;
        syncthing.enable = true;
        immich.enable = true;
        tailscale.enable = true;
      };
    }
  ]);
}
