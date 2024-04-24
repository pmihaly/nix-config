{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.nginx;
in
{
  options.modules.nginx = {
    enable = mkEnableOption "nginx";
  };
  config = mkIf cfg.enable {

    environment.persistence.${vars.persistDir}.directories = [ "/var/lib/acme" ];

    services.nginx = {
      enable = true;

      virtualHosts."${vars.domainName}" = {
        forceSSL = true;
        useACMEHost = vars.domainName;
        root = "${pkgs.nix.doc}/share/doc/nix/manual";
      };

      recommendedZstdSettings = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;
    };

    users.users.nginx.extraGroups = [ "acme" ];

    security.acme = {
      acceptTerms = true;
      defaults.email = "${vars.acmeEmail}";

      certs.${vars.domainName} = {
        extraDomainNames = [ "*.${vars.domainName}" ];

        dnsProvider = "porkbun";
        dnsPropagationCheck = true;
        credentialFiles = {
          PORKBUN_API_KEY_FILE = config.age.secrets."acme/porkbun-api-key".path;
          PORKBUN_SECRET_API_KEY_FILE = config.age.secrets."acme/porkbun-secret-key".path;
        };
      };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        443
      ];
    };

    modules.authelia.bypassDomains = [ vars.domainName ];
  };
}
