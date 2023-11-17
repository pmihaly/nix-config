{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.authelia;

in {
  options.modules.authelia = {
    enable = mkEnableOption "authelia";
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
          jwtSecretFile = "${pkgs.writeText "jwtSecretFile" "supersecretkey"}";
          storageEncryptionKeyFile = "${pkgs.writeText "storageEncryptionKeyFile" "supersecretkeyaaaaaaaaaaaaaaaaaaaaaaaaaaa"}";
          sessionSecretFile = "${pkgs.writeText "sessionSecretFile" "supersecretkey"}";
        };
        settings = {
          server = {
            host = "127.0.0.1";
            port = 8081;
          };

          log = {
            level = "debug";
            format = "text";
          };

          authentication_backend = {
            password_reset.disable = false;
            file = {
              path = (pkgs.formats.yaml { }).generate "users.yml" {
                users = {
                  misi = {
                    displayname = "Misi";
                    # Generate with docker run authelia/authelia:latest authelia hash-password <your-password>
                    password = "$argon2id$v=19$m=65536,t=3,p=4$UnHIp1WfAoLPco0z+sKPcQ$lMTppDulG/SRD7u80yE5kyCGaC/cOJ2FKb0K3v1M2Fo";
                    email = "auth@mihaly.codes";
                    groups = [ "admins" ];
                  };
                };
              };
            };
          };

          access_control = {
            default_policy = "deny";
            rules = [
            {
              policy = "bypass";
              domain = [
                "authelia.skylake.mihaly.codes"
                "skylake.mihaly.codes"
              ];
            }
            {
              policy = "one_factor";
              domain = ["*.skylake.mihaly.codes"];
            }
            ];
          };

          default_2fa_method = "totp";

          session = {
            name = "authelia_session";
            expiration = "12h";
            inactivity = "45m";
            remember_me_duration = "1M";
            domain = "skylake.mihaly.codes";
            redis.host = "/run/redis-authelia-skylake/redis.sock";
          };

          regulation = {
            max_retries = 3;
            find_time = "5m";
            ban_time = "15m";
          };

          storage = {
            local = {
              path = "/var/lib/authelia-skylake/db.sqlite3";
            };
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

      # services.authelia.secrets.jwtSecretFile = config.age.secrets.autheliaJwtSecret.path;
   };
  });
}
