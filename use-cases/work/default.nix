{ platform, pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.work;

in {
  options.modules.work = {
    enable = mkEnableOption "work";
    username = mkOption { type = types.str; };
  };
  config = mkIf cfg.enable (mkMerge [

    {
      home-manager.users.${cfg.username} = {
        imports = [ ../../secrets/home-manager ];

        modules.vscode.enable = true;

        home.packages = with pkgs; [
          awscli
          git-lfs
          saml2aws
          openssl
          obsidian
          jwt-cli
          libossp_uuid # uuid from cli
          slack
        ];
      };
    }

    (optionalAttrs platform.isDarwin {
      homebrew.casks = [ "sequel-ace" "pycharm-ce" ];
    })
  ]);
}

