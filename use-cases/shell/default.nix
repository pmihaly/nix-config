{
  platform,
  pkgs,
  vars,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.shell;
  bookmarks = rec {
    h = "~";
    d = "~/Downloads";
    p = "~/personaldev";
    s = "~/Sync";
    n = "~/.nix-config";
    fio = p + "/finances/import/otp/in";
    fir = p + "/finances/import/revolut/in";
    fiw = p + "/finances/import/wise/in";
  };
in
{
  options.modules.shell = {
    enable = mkEnableOption "shell";
    extraBookmarks = mkOption {
      default = { };
      type = types.attrs;
    };
    extraAliases = mkOption {
      default = { };
      type = types.attrs;
    };
    extraEnv = mkOption {
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
      environment.shells = [ (getExe pkgs.bashInteractive) ];

      programs.nix-index.enableBashIntegration = false;
      programs.command-not-found.enable = false;

      services.openssh = {
        enable = true;
        openFirewall = true;
        settings.PasswordAuthentication = true;
        hostKeys = cfg.sshServer.hostKeys;
      };

      services.locate = {
        enable = true;
        prunePaths = [ vars.persistDir ];
      };
      environment.persistence.${vars.persistDir}.directories = [ config.services.locate.output ];
      environment.systemPackages = with pkgs; [ lsof ];

    })

    (optionalAttrs platform.isDarwin {
      environment.shells = [ pkgs.bashInteractive ];

      # nix-darwin only writes UserShell for users listed in knownUsers, so
      # without this the `shell` below never reaches the account. The matching
      # `uid` lives with the other user attrs in the machine config.
      users.knownUsers = [ vars.username ];
    })

    { users.users.${vars.username}.shell = pkgs.bashInteractive; }

    (optionalAttrs platform.isLinux {
      home-manager.users.${vars.username} = {
        xdg.userDirs = {
          enable = true;
          setSessionVariables = true;
        };
      };
    })

    {
      home-manager.users.${vars.username} = {
        imports = [ ../../modules/home-manager ];

        modules = {
          persistence.directories = [
            "personaldev"
            {
              directory = ".ssh";
              mode = "0700";
            }
          ];
          shell = {
            enable = true;
            bookmarks = bookmarks // cfg.extraBookmarks;
            aliases = cfg.extraAliases;
            env = cfg.extraEnv;
            rebuildSwitch = vars.rebuildSwitch;
          };

          nvim.enable = true;
          git.enable = true;
        };
      };
    }
  ]);
}
