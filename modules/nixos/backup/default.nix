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
  resticRepo = "s3:https://s3.amazonaws.com/misibackups/skylake";
  resticCli = pkgs.writeShellScriptBin "restic-cli" ''
    export RESTIC_REPOSITORY="${resticRepo}"
    export RESTIC_PASSWORD="''$(cat ${config.age.secrets."backup/skylake-restic".path})"

    set -o allexport
    source ${config.age.secrets."backup/skylake".path}

    ${pkgs.restic}/bin/restic "$@"
  '';
in
{
  options.modules.backup = {
    enable = mkEnableOption "backup";
  };
  config = mkIf cfg.enable {
    users.groups.backup.members = [ "${vars.username}" ];

    services.restic = {
      backups."skylake-backup" = {
        repository = "s3:https://s3.amazonaws.com/misibackups/skylake";
        environmentFile = config.age.secrets."backup/skylake".path;
        passwordFile = config.age.secrets."backup/skylake-restic".path;
        paths = [
          vars.serviceConfig
          vars.storage
        ];
        exclude = [ "${vars.storage}/Media" ];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
        };
        initialize = true;
      };
    };

    programs.zsh.shellAliases.restic = "${resticCli}/bin/restic-cli";

  };
}
