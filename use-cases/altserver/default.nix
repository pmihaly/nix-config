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

      systemd.tmpfiles.rules =
        let
          directories = [
            "${vars.storage}/Services/anisette"
          ];
        in
        (map (directory: "d ${directory} 0750 misi backup -") directories);

      services.usbmuxd = {
        enable = true;
        package = pkgs.usbmuxd2;
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
