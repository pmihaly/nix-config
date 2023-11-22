{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.authelia;

in {
  options.modules.authelia = {
    enable = mkEnableOption "authelia";
    bypassDomains = mkOption {
      default = [ ];
      type = types.listOf types.str;
    };
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "authelia";
    port = 8081;
    dashboard = {
      category = "Admin";
      name = "Authelia";
      logo = ./authelia.png;
    };
    extraConfig = {
      services.authelia.instances.skylake = {
        enable = true;
        secrets = {
          jwtSecretFile = config.age.secrets."authelia/jwt-secret".path;
          storageEncryptionKeyFile =
            config.age.secrets."authelia/storageEncriptionKey".path;
          sessionSecretFile = config.age.secrets."authelia/sessionSecret".path;
        };
        settings = {
          server = {
            host = "127.0.0.1";
            port = 8081;
          };
          telemetry = {
            metrics = {
              enable = config.modules.monitoring.enable;
              address = "http://localhost:${toString config.services.prometheus.port}";
            };
          };

          log = {
            level = "debug";
            format = "text";
          };

          # generate passwords using:
          # docker run authelia/authelia:latest authelia crypto hash generate argon2
          authentication_backend.file.path =
            config.age.secrets."authelia/users".path;

          access_control = {
            default_policy = "deny";
            rules = [
              {
                policy = "bypass";
                domain = cfg.bypassDomains ++ [ "authelia.${vars.domainName}" ];
              }
              {
                policy = "two_factor";
                domain = [ "*.${vars.domainName}" ];
              }
            ];
          };

          default_2fa_method = "totp";

          session = {
            name = "authelia_session";
            expiration = "12h";
            inactivity = "45m";
            remember_me_duration = "1M";
            domain = "${vars.domainName}";
            redis.host = "/run/redis-authelia-skylake/redis.sock";
          };

          regulation = {
            max_retries = 3;
            find_time = "5m";
            ban_time = "15m";
          };

          storage = {
            local = { path = "/var/lib/authelia-skylake/db.sqlite3"; };
          };

          notifier = {
            disable_startup_check = false;
            filesystem = {
              filename = "/var/lib/authelia-skylake/notification.txt";
            };
          };
        };
      };
      services.redis.servers.authelia-skylake = {
        enable = true;
        user = "authelia-skylake";
        port = 0;
        unixSocket = "/run/redis-authelia-skylake/redis.sock";
        unixSocketPerm = 600;
      };
    };
  });
}
