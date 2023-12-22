{ pkgs, lib, inputs, config, vars, ... }:

with lib;
let
  cfg = config.modules.hledger;
  stateDir = "${vars.storage}/Services/hledger";
  currentDate =
    builtins.match "(.{4})(.{2})(.{2}).*" inputs.self.lastModifiedDate;
  currentYear = builtins.head currentDate;
  currentMonth = trivial.pipe currentDate [ (lists.drop 1) builtins.head ];
  prevMonth = trivial.pipe currentMonth [ strings.toInt (x: x - 1) toString ];

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
    extraConfig = {
      systemd.tmpfiles.rules = [ "d ${stateDir} 0755 hledger hledger - -" ];

      systemd.services.copy-finances-output = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.coreutils}/bin/cp -R ${
              inputs.finances.packages."${pkgs.system}".default.outPath
            }/. ${stateDir}
            ${pkgs.coreutils}/bin/chmod -R 0755 ${stateDir}
            ${pkgs.coreutils}/bin/chown -R hledger:hledger ${stateDir}
          '';
        };
      };

      services.hledger-web = {
        enable = true;
        port = 5001;
        stateDir = stateDir;
        journalFiles = [ "2023.journal" ];
        baseUrl = "https://hledger.${vars.domainName}";
      };

      networking.firewall.allowedTCPPorts = [ 5001 ];

      modules.homer.services.Finances = {
        "plotlies current ${currentYear}-${currentMonth}" = {
          logo = ./hledger.png;
          url =
            "https://hledger.${vars.domainName}/export/${currentYear}-${currentMonth}-plotlies-monthly.html";
        };
        "plotlies prev ${currentYear}-${prevMonth}" = {
          logo = ./hledger.png;
          url =
            "https://hledger.${vars.domainName}/export/${currentYear}-${prevMonth}-plotlies-monthly.html";
        };
        "plotlies year ${currentYear}" = {
          logo = ./hledger.png;
          url =
            "https://hledger.${vars.domainName}/export/${currentYear}-plotlies.html";
        };
        "pnl" = {
          logo = ./hledger.png;
          url =
            "https://hledger.${vars.domainName}/export/${currentYear}-income-expenses.txt";
        };
      };
    };

    extraNginxConfigRoot.locations."/export" = {
      root = stateDir;
      extraConfig = ''
        auth_request /authelia;

        set $target_url $scheme://$http_host$request_uri;

        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;

        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;

        error_page 401 =302 https://authelia.${vars.domainName}/?rd=$target_url;
      '';
    };
  });
}
