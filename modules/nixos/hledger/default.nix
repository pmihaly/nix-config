{ pkgs, lib, inputs, config, vars, ... }:

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
    extraConfig = let stateDir = "${vars.storage}/Services/hledger";
    in {

      systemd.tmpfiles.rules = [ "d ${stateDir} 0700 hledger hledger - -" ];

      systemd.services.copy-finances-output = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.coreutils}/bin/cp -R ${
              inputs.finances.packages."${pkgs.system}".default.outPath
            }/. ${stateDir}
            ${pkgs.coreutils}/bin/chmod -R 0700 ${stateDir}
            ${pkgs.coreutils}/bin/chown -R hledger:hledger ${stateDir}
          '';
        };
      };

      services.hledger-web = {
        enable = true;
        port = 5001;
        stateDir = stateDir;
        journalFiles = [ "all.journal" ];
        baseUrl = "https://hledger.${vars.domainName}";
      };

      networking.firewall.allowedTCPPorts = [ 5001 ];
    };
  });
}
