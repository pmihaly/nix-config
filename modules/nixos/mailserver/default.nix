{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.mailserver;

in {
  options.modules.mailserver = { enable = mkEnableOption "mailserver"; };
  config = mkIf cfg.enable {

    security.acme = {
      acceptTerms = true;
      defaults.email = vars.acmeEmail;
    };

    mailserver = {
      enable = true;
      fqdn = "post-office.${vars.domainName}";
      domains = [ vars.domainName ];

      # A list of all login accounts. To create the password hashes, use
      # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
      loginAccounts = {
        "mihaly@mihaly.codes" = {
          # hashedPasswordFile =
          #   config.age.secrets."mailserver/mihaly-password".path;
          hashedPassword =
            "$2b$05$RIwMi30NG5UxDhtANdvjDu2T2ov2hEVlv8/BNjaAFpWjAsb1hQn.K";
        };
      };

      # Use Let's Encrypt certificates. Note that this needs to set up a stripped
      # down nginx and opens port 80.
      certificateScheme = "acme-nginx";
    };

    services.postfix = {
      mapFiles."sasl_passwd" = config.age.secrets."mailserver/aws-ses-sasl".path;

      extraConfig = ''
        smtp_sasl_auth_enable = yes
        smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
        smtp_sasl_security_options = noanonymous
        smtp_sasl_tls_security_options = noanonymous
        smtp_sasl_mechanism_filter = AUTH LOGIN
        relayhost = [RELAY_IP]:587
      '';
    };

    services.roundcube = {
      enable = true;
      # this is the url of the vhost, not necessarily the same as the fqdn of
      # the mailserver
      hostName = "webmail.post-office.${vars.domainName}";
      extraConfig = ''
        # starttls needed for authentication, so the fqdn required to match
        # the certificate
        $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
        $config['smtp_user'] = "%u";
        $config['smtp_pass'] = "%p";
      '';
    };

    services.nginx.enable = true;

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
