{
  platform,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.altserver;
in
{
  options.modules.altserver = {
    enable = mkEnableOption "altserver";
  };
  config = mkIf cfg.enable (
    optionalAttrs platform.isLinux {

      systemd.tmpfiles.rules = ["d ${vars.storage}/Services/anisette 0750 misi multimedia -"];

      programs.zsh.shellAliases.altserver = "ALTSERVER_ANISETTE_SERVER='http://localhost:6969' ${getExe pkgs.altserver-linux}";

      services.usbmuxd = {
        enable = true;
      };

      home-manager.users.${vars.username} = {
        home.packages = with pkgs; [
          libimobiledevice
          altserver-linux
        ];
      };

      virtualisation.oci-containers.containers.alt_anisette_server = {
        image = "dadoum/anisette-v3-server";
        ports = [
          "6969:6969"
        ];
        volumes = [
          "${vars.storage}/Services/anisette:/home/Alcoholic/.config/anisette-v3/lib/"
        ];
      };
    }
  );
}
