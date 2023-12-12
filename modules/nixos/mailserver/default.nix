{ lib, config, ... }:

with lib;
let cfg = config.modules.mailserver;

in {
  options.modules.mailserver = { enable = mkEnableOption "mailserver"; };
  config = mkIf cfg.enable {
    mailserver = {
      enable = true;
      fqdn = "mail.mihaly.codes";
      domains = [ "mihaly.codes" ];

      # A list of all login accounts. To create the password hashes, use
      # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
      loginAccounts = {
        # "mihaly@mihaly.codes" = {
        #   hashedPasswordFile = "/a/file/containing/a/hashed/password";
        # };
      };

      # Use Let's Encrypt certificates. Note that this needs to set up a stripped
      # down nginx and opens port 80.
      certificateScheme = "acme-nginx";
    };
  };
}
