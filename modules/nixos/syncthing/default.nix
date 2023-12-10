{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.syncthing;

in {
  options.modules.syncthing = { enable = mkEnableOption "syncthing"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "syncthing";
    port = 8384;
    dashboard = {
      category = "Documents";
      name = "Syncthing";
      logo = ./syncthing.png;
    };
    extraConfig = let
      directories = [
        "${vars.serviceConfig}/syncthing"
        "${vars.serviceConfig}/syncthing/db"
      ];
      macbook = "mihalypapp-MacBook-Pro";
      phone = "Redmi Note 9S";
    in {

      systemd.tmpfiles.rules =
        (map (directory: "d ${directory} 0775 syncthing backup")
          directories);

      services.syncthing = {
        enable = true;
        configDir = "${vars.serviceConfig}/syncthing";
        dataDir = "${vars.serviceConfig}/syncthing/db";
        overrideDevices = true;
        overrideFolders = true;
        openDefaultPorts = true;
        guiAddress = "0.0.0.0:8384";
        group = "backup";
        settings = {
          options.urAccepted = -1;
          devices = {
            "${macbook}" = {
              id =
                "H5FVJNM-LK4LXBL-DI64DJD-ZKXX3XN-WA7MXFS-CT7ECUO-FANJ4BH-276ZJQL";
            };
            "${phone}" = {
              id =
                "QCJS2V6-CEGZ6HK-XKMEQBK-SSEZN7U-IBH3FQU-TW53QZR-JG6BLHN-RQ3DRQF";
            };
          };
          folders = {
            "papers-consume" = {
              path = "${vars.storage}/Services/paperless/consume";
              devices = [ "${macbook}" "${phone}" ];
            };
            "papers-backup" = {
              path = "${vars.storage}/Services/paperless/media";
              devices = [ "${macbook}" "${phone}" ];
              ignorePerms = false;
              versioning.type = "staggered";
            };
          };
        };
      };
    };
  });
}
