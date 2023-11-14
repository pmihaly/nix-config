{ lib, config, ... }:

with lib;
let cfg = config.modules.nginx;

in {
  options.modules.nginx = { enable = mkEnableOption "nginx"; };
  config = mkIf cfg.enable {
    virtualisation.arion.projects.skylab.settings.services = {
      nginx = { pkgs, lib, ... }: {
        nixos.useSystemd = true;
        nixos.configuration = {
          boot.tmp.useTmpfs = true;

          services.nginx = {
            enable = true;
            virtualHosts.localhost.root = "${pkgs.nix.doc}/share/doc/nix/manual";
            recommendedZstdSettings = true;
            recommendedTlsSettings = true;
            recommendedProxySettings = true;
            recommendedOptimisation = true;
            recommendedGzipSettings = true;
            recommendedBrotliSettings = true;
          };

          services.nscd.enable = false;
          system.nssModules = lib.mkForce [];
          systemd.services.nginx.serviceConfig.AmbientCapabilities =
            lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
        };
        service.useHostStore = true;
        service.ports = [
          "8000:80"
        ];
      };
    };
  };
}
