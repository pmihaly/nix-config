{
  inputs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.immich;
in
{
  options.modules.immich = {
    enable = mkEnableOption "immich";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "immich";
    port = 2283;
    dashboard = {
      category = "Documents";
      name = "Immich";
      logo = ./immich.png;
    };
    extraConfig =
      let
        directories = [
          "${vars.storage}/Media/Pictures"
          "${vars.storage}/Services/immich/postgres-v3"
        ];
        environment = {
          TZ = vars.timeZone;
          # Migrated to v3.1.0 (2026-08-23): v3 requires the `vector` (pgvector) or
          # `vchord` extension — the old pgvecto-rs image only provided `vectors`,
          # which crashed v3 ("No vector extension found"), so we were stuck on v2.7.5.
          # New DB built on docker.io/pgvector/pgvector:pg14-trixie (pg14 is accepted:
          # POSTGRES_VERSION_RANGE '>=14.0.0', pgvector 0.8.6 satisfies '>=0.5 <1'),
          # restored from db-v2.7.5-pre-v3-20260823.dump (kept in the immich dir as
          # rollback). v3 applies its 20 remaining kysely migrations on first start and
          # recreates clip_index/face_index as pgvector HNSW via schema sync.
          # ROLLBACK: restore the dump into the old `postgres` data dir + revert this file.
          IMMICH_VERSION = "v3.1.0";
          DB_HOSTNAME = "immich-database";
          DB_USERNAME = "postgres";
          DB_PASSWORD = "postgres";
          DB_DATABASE_NAME = "immich";
          REDIS_HOSTNAME = "immich-redis";
        };
      in
      {

        systemd.tmpfiles.rules = (map (directory: "d ${directory} 0775 misi backup") directories);

        virtualisation.podman.defaultNetwork.settings.dns_enabled = true;
        environment.persistence.${vars.persistDir}.directories = [ "/var/lib/containers" ];
        services.nginx.clientMaxBodySize = "1G";

        virtualisation.oci-containers.containers = {

          immich-server = {
            image = "ghcr.io/immich-app/immich-server:v3.1.0@sha256:079cc990b26a88d71f96027341c67329cb11829d4c341ce33b3718fe0f84cbfa";
            inherit environment;
            ports = [ "2283:2283" ];
            volumes = [
              "${vars.storage}/Media/Pictures:/usr/src/app/upload"
              "/etc/localtime:/etc/localtime:ro"
            ];
            dependsOn = [
              "immich-redis"
              "immich-database"
            ];
          };

          immich-machine-learning = {
            image = "ghcr.io/immich-app/immich-machine-learning:v3.1.0@sha256:5a0839dc5303cd7215bcd2180a26aed3af41675aefb3e75e5157e9f10ad16e6e";
            inherit environment;
            volumes = [ "model-cache:/cache" ];
          };

          immich-redis = {
            image = "registry.hub.docker.com/library/redis:6.2-alpine@sha256:84882e87b54734154586e5f8abd4dce69fe7311315e2fc6d67c29614c8de2672";
            inherit environment;
          };

          immich-database = {
            # pg14 is fine for v3 (server requires >=14.0.0); pgvector 0.8.6 in this
            # image provides the `vector` extension v3 accepts (Vector or VectorChord).
            image = "docker.io/pgvector/pgvector:pg14-trixie@sha256:2ab5b03acb45471246f52692764ed9590fc34288de2b5bce68da53ef1b8c1a35";
            environment = {
              POSTGRES_PASSWORD = environment.DB_PASSWORD;
              POSTGRES_USER = environment.DB_USERNAME;
              POSTGRES_DB = environment.DB_DATABASE_NAME;
            };
            volumes = [ "${vars.storage}/Services/immich/postgres-v3:/var/lib/postgresql/data" ];
          };
        };
      };
  });
}
