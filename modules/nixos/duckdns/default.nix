{ pkgs, lib, config, vars, ... }:

with lib;
let cfg = config.modules.duckdns;

in {
  options.modules.duckdns = { enable = mkEnableOption "duckdns"; };
  config = mkIf cfg.enable {
    systemd.services.duckdns = {
      after = [ "network.target" ];
      description = "Free dynamic DNS hosted on AWS";
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
          token=$(cat ${config.age.secrets."duckdns/token".path})
          ${pkgs.curl}/bin/curl \
          "https://www.duckdns.org/update?domains=${vars.duckdnsDomainName}&token=$token&verbose=true"
      '';
    };

    systemd.timers.duckdns = {
      wantedBy = [ "timers.target" ];
      partOf = [ "duckdns.service" ];
      timerConfig = {OnCalendar = "Weekly"; Persistent = true;};
    };
  };
}
