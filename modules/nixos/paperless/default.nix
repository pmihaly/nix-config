{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.paperless;

in {
  options.modules.paperless = { enable = mkEnableOption "paperless"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "paperless";
    port = 28981;
    dashboard = {
      category = "Documents";
      name = "Paperless-ngx";
      logo = ./paperless.svg;
    };
    extraConfig = let directories = [ "${vars.serviceConfig}/paperless" "${vars.serviceConfig}/paperless/media" ];
    in {

      systemd.tmpfiles.rules =
        (map (directory: "d ${directory} 0775 paperless backup") directories);

      services.paperless = {
        enable = true;
        dataDir = "${vars.storage}/Services/paperless";
        mediaDir = "${vars.storage}/Services/paperless/media";
        consumptionDir = "${vars.storage}/Services/paperless/consume";
        consumptionDirIsPublic = true;
        passwordFile = builtins.toFile "paperles-passwordfile"
          "some-admin-password-i-dont-care-about-because-i-use-authelia";
        extraConfig = {
          PAPERLESS_ADMIN_USER = "🧙";
          PAPERLESS_AUTO_LOGIN_USERNAME = "🧙";
          PAPERLESS_OCR_LANGUAGE = "hun+eng";
          PAPERLESS_URL = "https://paperless.${vars.domainName}";
        };
      };

      networking.firewall.allowedTCPPorts = [ 28981 ];
    };

  });
}
