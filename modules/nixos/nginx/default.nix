{ lib, config, ... }:

with lib;
let cfg = config.modules.nginx;

in {
  options.modules.nginx = { enable = mkEnableOption "nginx"; };
  config = mkIf cfg.enable {
    virtualisation.arion.projects.skylab.settings.services = {
      nginx = { pkgs, lib, ... }: {
        nixos.useSystemd = true;
        nixos.configuration.boot.tmpOnTmpfs = true;
        nixos.configuration.services.nginx.enable = true;
        nixos.configuration.services.nginx.virtualHosts.localhost.root = "${pkgs.nix.doc}/share/doc/nix/manual";
        nixos.configuration.services.nscd.enable = false;
        nixos.configuration.system.nssModules = lib.mkForce [];
        nixos.configuration.systemd.services.nginx.serviceConfig.AmbientCapabilities =
          lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
        service.useHostStore = true;
        service.ports = [
          "8000:80"
        ];
      };
    };
  };
}
