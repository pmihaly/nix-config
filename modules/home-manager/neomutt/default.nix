{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.neomutt;
in
{
  options.modules.neomutt = {
    enable = mkEnableOption "neomutt";
  };
  imports = [ ../../../secrets/home-manager ];
  config = mkIf cfg.enable {

    modules.persistence.directories = [ "Maildir" ];

    accounts.email.accounts = {
      "mihaly_mihaly.codes" = rec {
        address = "mihaly@mihaly.codes";
        userName = address;
        realName = "Mihaly Papp";
        passwordCommand = "cat ${config.age.secrets."email/password/mihaly_mihaly.codes".path}";
        primary = true;
        imap.host = "imap.mailbox.org";
        smtp.host = "smtp.mailbox.org";
        neomutt.enable = true;
        mbsync = {
          enable = true;
          create = "maildir";
        };
        msmtp.enable = true;
        notmuch.enable = true;
      };
    };

    programs.neomutt = {
      enable = true;
      vimKeys = true;
    };

    programs.mbsync.enable = true;
    programs.msmtp.enable = true;
    programs.notmuch = {
      enable = true;
      hooks = {
        preNew = "mbsync --all";
      };
    };
  };
}
