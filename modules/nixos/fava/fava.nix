{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.fava;

in {
  options.modules.fava = {
    enable = mkEnableOption "fava";
    beanCountFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
    };
    port = mkOption {
      type = types.port;
      default = 5000;
    };
    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    openFirewall = mkOption {
      type = types.nullOr types.bool;
      default = false;
    };
    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.fava;
    };
    user = mkOption {
      type = types.nullOr types.str;
      default = "fava";
    };
    group = mkOption {
      type = types.nullOr types.str;
      default = "fava";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ cfg.package ];

    systemd.tmpfiles.rules =
      map (file: "f ${file} 0770 ${cfg.user} ${cfg.group}") cfg.beanCountFiles;

    systemd.services.fava = {
      after = [ "network.target" ];
      description = "Web interface for Beancount";
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];
      serviceConfig = {
        ExecStart = ''
          ${cfg.package}/bin/fava \
          --port ${toString cfg.port} \
          ${escapeShellArgs cfg.extraFlags} \
          ${concatStringsSep " " cfg.beanCountFiles} \
        '';
        Restart = "on-success";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    networking.firewall =
      (mkIf (cfg.openFirewall) { allowedTCPPorts = [ cfg.port ]; });

    users.users = mkIf (cfg.user == "fava") {
      fava = {
        group = cfg.group;
        uid = null;
        description = "Fava user";
        isSystemUser = true;
      };
    };

    users.groups = mkIf (cfg.group == "fava") { fava = { gid = null; }; };
  };
}
