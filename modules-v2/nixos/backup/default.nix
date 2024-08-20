{
  pkgs,
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
      resticCli = pkgs.writeShellScriptBin "restic-cli" ''
        export RESTIC_REPOSITORY="${resticRepo}"
        export RESTIC_PASSWORD="''$(cat ${config.age.secrets."backup/restic".path})"

        set -o allexport
        source ${config.age.secrets."backup/s3-access".path}

        ${pkgs.restic}/bin/restic "$@"
      '';
    in
    mkIf cfg.enable {
      users.groups.backup.members = [ "${vars.username}" ];

      services.restic = {
        backups."${cfg.machineId}-backup" = {
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
        };
      };

      programs.zsh.shellAliases.restic = "${resticCli}/bin/restic-cli";
    };
}
