{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.immich;

in {
  options.modules.immich = { enable = mkEnableOption "immich"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "immich";
    port = 3001;
    dashboard = {
      category = "Media";
      name = "immich";
      logo = ./immich.png;
    };
    extraConfig = let
      directories = [
        "${vars.storage}/Media/Pictures"
        "${vars.storage}/Services/Immich/postgres"
      ];
      environment = {
        TZ = vars.timeZone;
        IMMICH_VERSION = "v1.102.3";
        DB_HOSTNAME = "immich-database";
        DB_USERNAME = "postgres";
        DB_PASSWORD = "postgres";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "immich-redis";
      };
    in {

      systemd.tmpfiles.rules =
        (map (directory: "d ${directory} 0775 misi backup") directories);

      virtualisation.podman.defaultNetwork.settings.dns_enabled = true;

      virtualisation.oci-containers.containers = {

        immich-server = {
          image =
            "ghcr.io/immich-app/immich-server:${environment.IMMICH_VERSION}";
          inherit environment;
          cmd = [ "start.sh" "immich" ];
          ports = [ "2283:3001" ];
          volumes = [
            "${vars.storage}/Media/Pictures:/usr/src/app/upload"
            "/etc/localtime:/etc/localtime:ro"
          ];
          dependsOn = [ "immich-redis" "immich-database" ];
        };

        # TODO hw acc
        immich-microservices = {
          image =
            "ghcr.io/immich-app/immich-server:${environment.IMMICH_VERSION}";
          inherit environment;
          cmd = [ "start.sh" "microservices" ];
          volumes = [
            "${vars.storage}/Media/Pictures:/usr/src/app/upload"
            "/etc/localtime:/etc/localtime:ro"
          ];
          dependsOn = [ "immich-redis" "immich-database" ];
        };

        # TODO hw acc
        immich-machine-learning = {
          image =
            "ghcr.io/immich-app/immich-machine-learning:${environment.IMMICH_VERSION}";
          inherit environment;
          volumes = [ "model-cache:/cache" ];
        };

        immich-redis = {
          image =
            "registry.hub.docker.com/library/redis:6.2-alpine@sha256:84882e87b54734154586e5f8abd4dce69fe7311315e2fc6d67c29614c8de2672";
          inherit environment;
        };

        immich-database = {
          image =
            "registry.hub.docker.com/tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0";
          environment = {
            POSTGRES_PASSWORD = environment.DB_PASSWORD;
            POSTGRES_USER = environment.DB_USERNAME;
            POSTGRES_DB = environment.DB_DATABASE_NAME;
          };
          volumes = [
            "${vars.storage}/Services/Immich/postgres:/var/lib/postgres/data"
          ];
        };

      };

    };
  });
}
