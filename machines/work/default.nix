{
  pkgs,
  vars,
  lib,
  ...
}:
with lib;
let
  workvars = builtins.fromTOML (
    builtins.readFile "/Users/${vars.username}/.nix-config/machines/work/workvars.toml"
  );
  envs = [
  ];
in
rec {
  imports = [ ../../use-cases ];

  modules = {
    nix.enable = true;

    shell = {
      enable = true;
      extraBookmarks = {
        su = "'~/Library/Application Support'";
        w = "~/work";
      };
    };

    gui = {
      enable = true;
      terminal-font-size = "14.0";
    };
  };

  ids.uids.nixbld = 350;

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";

    modules = {
      vscode.enable = true;
    };

    programs.firefox.profiles.misi = {
      bookmarks.settings = [
        {
          name = "jira";
          url = "${workvars.jira-url}/PHOENIX";
        }
        {
          name = "gmail";
          url = "gmail.com";
        }
        {
          name = "calendar";
          url = "calendar.google.com";
        }
      ]
      ++ lib.mapAttrsToList (key: val: {
        name = key;
        url = val;
      }) workvars.extra-bookmarks
      ++
        builtins.concatMap
          (service: [
            {
              name = "${service} mr";
              url = "https://gitlab.${workvars.domain}/lensa/phoenix/${service}/-/merge_requests";
            }
            {
              name = "${service} pipe";
              url = "https://gitlab.${workvars.domain}/lensa/phoenix/${service}/-/pipelines";
            }
          ])
          [
          ];
    };

    home.packages = with pkgs; [
      slack
      mariadb # vim dadbod
    ];

    programs.nixvim = {
      globals.dbs = [
        {
          name = "local";
          url = "mysql://root@127.0.0.1:3306";
        }
      ]
      ++ map (env: {
        name = "${env} (tun)";
        url = "mysql://${workvars.demo-db-user}:${workvars.demo-db-password}@${env}-mysql8.demo:3307";
      }) envs;
    };
  };

  homebrew.casks = [
    "docker"
    "flux"
    "google-chrome"
  ];

  users.users.${vars.username}.home = "/Users/${vars.username}";
  system.primaryUser = vars.username;

  system.stateVersion = 5;
}
