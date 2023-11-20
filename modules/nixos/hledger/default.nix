{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.hledger;

in {
  options.modules.hledger = { enable = mkEnableOption "hledger"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "hledger";
    port = 5001;
    dashboard = {
      category = "Finances";
      name = "hledger";
      logo = ./hledger.png;
    };
    extraConfig =
      let
      directories = [ "${vars.storage}/Services/hledger" ];
      files = [ "${vars.storage}/Services/hledger/hledger.journal" ];
      in {

        systemd.tmpfiles.rules =
          (map (file: "f ${file} 0775 hledger hledger") files)
          ++ (map (directory: "d ${directory} 0775 hledger hledger") directories);

        services.hledger-web = {
          enable = true;
          port = 5001;
          stateDir = "${vars.storage}/Services/hledger";
          journalFiles = [ "hledger.journal" ];
          baseUrl = "https://hledger.${vars.domainName}";
        };
        networking.firewall.allowedTCPPorts = [ 5001 ];
      };
  });
}
