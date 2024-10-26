{
  platform,
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
    optionalAttrs platform.isLinux (mkService {
      subdomain = "altserver-windows";
      port = 8006;
      dashboard = {
        category = "Misc";
        name = "Altserver";
        logo = ./windows.svg;
      };
      extraConfig = {
        systemd.tmpfiles.rules = [
          "d ${vars.storage}/Services/altserver-windows 0755 ${vars.username} multimedia - -"
        ];

        networking.firewall = {
          allowedTCPPorts = [
            8006
            3389
          ];
          allowedUDPPorts = [ 3389 ];
        };

        virtualisation.oci-containers.containers.altserver-windows = {
          image = "dockurr/windows";
          environment = {
            VERSION = "win11";
            USERNAME = "altserver";
            PASSWORD = "altserver";
            ARGUMENTS = "-device usb-host,vendorid=0x05ac,productid=0x12a8"; # should be working for any iphone
          };
          ports = [
            "8006:8006"
            "3389:3389/tcp"
            "3389:3389/udp"
          ];
          volumes = [
            "${vars.storage}/Services/altserver-windows:/storage"
          ];
          extraOptions = [
            "--device=/dev/kvm"
            "--device=/dev/bus/usb"
            "--device=/dev/net/tun"
            "--cap-add=all"
          ];
        };
      };
    })
  );
}
