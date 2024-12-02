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
  config =
    let
      resticRepo = "s3:https://s3.amazonaws.com/misibackups/${cfg.machineId}";
    in
    mkIf cfg.enable {
      users.groups.backup.members = [ "${vars.username}" ];

      services.restic.backups."${cfg.machineId}-backup" = {
        repository = resticRepo;
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

      programs.zsh.shellAliases.restic = "restic-${cfg.machineId}-backup";
    };
}
