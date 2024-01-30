{ platform, pkgs, lib, config, ... }:

with lib;
let
  cfg = config.modules.shell;
  bookmarks = rec {
    h = "~";
    d = "~/Downloads";
    p = "~/personaldev";
    o = "~/Sync/org";
    s = "~/Sync";
    n = "~/.nix-config";
    fio = p + "/finances/import/otp/in";
    fir = p + "/finances/import/revolut/in";
    fiw = p + "/finances/import/wise/in";
  };

in {
  options.modules.shell = {
    enable = mkEnableOption "shell";
    username = mkOption { type = types.str; };
    extraBookmarks = mkOption {
      default = { };
      type = types.attrs;
    };
    sshServer = {
      hostKeys = mkOption {
        default = [ ];
        type = types.listOf types.attrs;
      };
    };
  };
  config = mkIf cfg.enable (mkMerge [

    (optionalAttrs platform.isLinux {
      programs.zsh.enable = true;
      services.openssh = {
        enable = true;
        openFirewall = true;
        ports = [ 69 ];
        settings.PasswordAuthentication = false;
        hostKeys = cfg.sshServer.hostKeys;
      };
    })

    { users.users.${cfg.username}.shell = pkgs.zsh; }

    (optionalAttrs platform.isLinux {
      home-manager.users.${cfg.username}.xdg.userDirs.enable = true;
    })

    {
      home-manager.users.${cfg.username} = {
        imports = [ ../../modules/home-manager ];

        modules = {
          shell = {
            enable = true;
            bookmarks = bookmarks // cfg.extraBookmarks;
          };

          lf = {
            enable = true;
            bookmarks = bookmarks // cfg.extraBookmarks;
          };

          nvim.enable = true;
          git.enable = true;
        };
      };
    }

  ]);
}

