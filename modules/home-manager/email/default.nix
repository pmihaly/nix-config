{
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.email;
in
{
  options.modules.email = {
    enable = mkEnableOption "email";
  };
  imports = [ ../../../secrets/home-manager ];
  config = mkIf cfg.enable {

    accounts.email.accounts = {
      "mihaly_mihaly.codes" = rec {
        address = "mihaly@mihaly.codes";
        userName = address;
        realName = "Mihaly Papp";
        passwordCommand = "cat ${config.age.secrets."email/password/mihaly_mihaly.codes".path}";
        primary = true;
        imap.host = "imap.mailbox.org";
        smtp.host = "smtp.mailbox.org";
        aerc.enable = true;
      };
    };

    programs.aerc = {
      enable = true;
      extraConfig.general.unsafe-accounts-conf = true;
    };
  };
}
