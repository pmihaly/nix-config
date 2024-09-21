{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.backup;
in
{
  options.modules.notification-server = {
    enable = mkEnableOption "notification-server";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "gotify";
    port = 8113;
    dashboard = {
      category = "Misc";
      name = "Gotify";
      logo = ./gotify.svg;
    };
    extraConfig = {

      environment.persistence.${vars.persistDir} = {
        directories = [
          {
            directory = "/var/lib/gotify-server";
            mode = "0700";
            user = "gotify-server";
          }
        ];
      };

      systemd.services.gotify-server = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Simple server for sending and receiving messages";

        environment = {
          GOTIFY_SERVER_PORT = toString 8113;
        };

        serviceConfig = {
          WorkingDirectory = "/var/lib/gotify-server";
          Restart = "always";
          ExecStart = "${pkgs.gotify-server}/bin/server";
        };
      };
    };
  });
}
