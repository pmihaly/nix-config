{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.nginx;

in {
  options.modules.nginx = { enable = mkEnableOption "nginx"; };
  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;

      virtualHosts."skylake.mihaly.codes" = {
        forceSSL = true;
        enableACME = true;
        root = "${pkgs.nix.doc}/share/doc/nix/manual";
      };

      recommendedZstdSettings = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "skylab-certs@mihaly.codes";
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ];
    };
  };
}
