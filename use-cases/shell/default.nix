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
    sshServer = {
      hostKeys = mkOption {
        default = [ ];
        type = types.listOf types.attrs;
      };
    };
  };
  config = mkIf cfg.enable (mkMerge [

    (optionalAttrs platform.isLinux {
      environment.shells = [ (getExe pkgs.bash) ];

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

    { users.users.${vars.username}.shell = pkgs.bash; }

    (optionalAttrs platform.isLinux { home-manager.users.${vars.username}.xdg.userDirs.enable = true; })

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
            rebuildSwitch = vars.rebuildSwitch;
          };

          nvim.enable = true;
          git.enable = true;
        };
      };
    }
  ]);
}
