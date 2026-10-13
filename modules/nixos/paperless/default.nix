{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.paperless;
in
{
  options.modules.paperless = {
    enable = mkEnableOption "paperless";
  };
  config = mkIf cfg.enable (mkService {
    subdomain = "paperless";
    port = 28981;
    dashboard = {
      category = "Documents";
      name = "Paperless-ngx";
      logo = ./paperless.svg;
    };
    extraConfig =
      let
        directories = [
          "${vars.storage}/Services/paperless"
          "${vars.storage}/Services/paperless/media"
        ];
      in
      {

        # paperless runs as misi (services.paperless.user below), but the
        # nixpkgs paperless module only adds the redis-paperless group when the
        # service uses its default "paperless" user. Without this membership the
        # paperless processes cannot reach the redis unix socket
        # /run/redis-paperless/redis.sock (EACCES; services stay dead or stuck
        # retrying manage.py migrate). Broken by the 2026-10-01 nixpkgs bump that
        # moved the redis instance to a dedicated redis-paperless user/group.
        users.users.misi.extraGroups = [
          config.services.redis.servers.paperless.group
        ];

        systemd.tmpfiles.rules = (map (directory: "d ${directory} 0750 misi backup -") directories);

        services.paperless = {
          enable = true;
          address = "0.0.0.0";
          dataDir = "${vars.storage}/Services/paperless";
          mediaDir = "${vars.storage}/Services/paperless/media";
          consumptionDir = "${vars.storage}/Services/paperless/consume";
          user = "misi";
          consumptionDirIsPublic = true;
          passwordFile = builtins.toFile "paperles-passwordfile" "some-admin-password-i-dont-care-about-because-i-use-authelia";
          settings = {
            PAPERLESS_ADMIN_USER = "🧙";
            PAPERLESS_AUTO_LOGIN_USERNAME = "🧙";
            PAPERLESS_OCR_LANGUAGE = "hun+eng";
            PAPERLESS_URL = "https://paperless.${vars.domainName}";
          };
        };
      };
  });
}
