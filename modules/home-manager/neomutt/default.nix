{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.neomutt;

in {
  options.modules.neomutt = { enable = mkEnableOption "neomutt"; };
  imports = [ ../../../secrets/home-manager ];
  config = mkIf cfg.enable {

    modules.persistence.directories = [ "Maildir" ];

    accounts.email.accounts = {
      "mihaly_mihaly.codes" = rec {
        address = "mihaly@mihaly.codes";
        userName = address;
        realName = "Mihaly Papp";
        passwordCommand =
          "cat ${config.age.secrets."email/password/mihaly_mihaly.codes".path}";
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
      extraConfig = builtins.concatStringsSep "\n" [
        (builtins.readFile (pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "neomutt";
          rev = "f6ce83da47cc36d5639b0d54e7f5f63cdaf69f11";
          hash = "sha256-ye16nP2DL4VytDKB+JdMkBXU+Y9Z4dHmY+DsPcR2EG0=";
        } + /neomuttrc))
      ];
    };

    programs.mbsync.enable = true;
    programs.msmtp.enable = true;
    programs.notmuch = {
      enable = true;
      hooks = { preNew = "mbsync --all"; };
    };

  };
}
