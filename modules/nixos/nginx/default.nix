{ pkgs, lib, config, vars, ... }:

with lib;
let cfg = config.modules.nginx;

in {
  options.modules.nginx = { enable = mkEnableOption "nginx"; };
  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;

      virtualHosts."${vars.domainName}" = {
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
      defaults.email = "${vars.acmeEmail}";
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ];
    };

    modules.authelia.bypassDomains = [ vars.domainName ];
  };
}
