{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.backup;
in
{
  options.modules.backup = {
    enable = mkEnableOption "backup";
    machineId = mkOption { type = types.str; };
    include = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    timer = mkOption {
      type = types.str;
      default = "hourly";
    };
  };
  config = mkIf cfg.enable {
    users.groups.backup.members = [ "${vars.username}" ];

    services.restic.backups."${cfg.machineId}-backup" = {
      repository = "s3:https://s3.amazonaws.com/misibackups/${cfg.machineId}";
      environmentFile = config.age.secrets."backup/s3-access".path;
      passwordFile = config.age.secrets."backup/restic".path;
      paths = cfg.include;
      exclude = cfg.exclude;
      timerConfig = {
        OnCalendar = cfg.timer;
        Persistent = true;
      };
      initialize = true;
      createWrapper = true;
    };

    home-manager.users.${vars.username}.programs.nushell.shellAliases.restic =
      "restic-${cfg.machineId}-backup";
  };
}
