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
          hashedPasswordFile = config.age.secrets."mailserver/mihaly-password".path;
        };
      };

      # Use Let's Encrypt certificates. Note that this needs to set up a stripped
      # down nginx and opens port 80.
      certificateScheme = "acme-nginx";
    };
  };
}
