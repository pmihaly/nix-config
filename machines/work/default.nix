{
  pkgs,
  vars,
  lib,
  ...
}:
let
  workvars = builtins.fromJSON (
    builtins.readFile "/Users/${vars.username}/.nix-config/machines/work/workvars.json"
  );
in
{
  imports = [ ../../use-cases ];

  modules = {
    nix.enable = true;

    shell = {
      enable = true;
      extraBookmarks = {
        w = "~/lensadev";
      };
    };

    gui = {
      enable = true;
      terminal-font-size = "13.0";
    };
    style.enable = true;
  };

  ids.uids.nixbld = 350;

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";

    modules = {
      vscode.enable = true;
    };

    programs.firefox.profiles.misi = {
      bookmarks =
        [
          {
            name = "jumpcloud";
            url = "https://console.jumpcloud.com";
          }
          {
            name = "jira";
            url = "${workvars.jira-url}/PHOENIX";
          }
          {
            name = "datadog";
            url = "https://app.datadoghq.com/dashboard";
          }
          {
            name = "prod graylog";
            url = "https://graylog.${workvars.domain}";
          }
          {
            name = "local graylog";
            url = "localhost:9988";
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
              "career-and-social-infra"
              "career-and-social-sites"
              "career-assistant"
              "company-and-job-title"
              "company-and-job-title-moderation"
              "company-match"
              "phoenix-overview"
              "scripts"
              "social-feed-engine"
              "video-catalog"
              "video-director"
              "video-editor"
              "video-infra"
              "video-player"
              "video-streamer"
            ];
    };

    programs.lazygit.settings.services = {
      "gsh.${workvars.domain}" = "gitlab:gitlab.${workvars.domain}";
    };

    programs.zsh.shellAliases = {
      d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
      dn = "d && nvim";
      ticket = ''git branch --show-current | grep -oE "[A-Z]+-[0-9]+" | tr -d "\n"'';
      jira = "ticket | xargs -I{} open '${workvars.jira-url}/{}'";
      mr = "open \"https://gitlab.${workvars.domain}/lensa/phoenix/$(basename \"$(pwd)\")/-/merge_requests?scope=all&state=opened&search=$(ticket)\"";
      devenv = "set -o allexport && source config/dev.env";
      so = "source ./.ve/bin/activate ; devenv";
      gl = "mkdir -p ~/tun ; pushd ~/tun ; ssh -T graylog-staging-tunnel & (sleep 4 ; open http://localhost:9988)";
    };

    home.packages = with pkgs; [
      awscli
      git-lfs
      saml2aws
      openssl
      obsidian
      jwt-cli
      libossp_uuid # uuid from cli
      slack
      gnumake
      mysql84 # vim dadbod
      jetbrains.pycharm-community-bin
    ];

    programs.nixvim.globals.dbs =
      [
        {
          name = "local";
          url = "mysql://root@127.0.0.1:3306";
        }
        {
          name = "staging (tun)";
          url = workvars.staging-mysql-url;
        }
      ]
      ++ map
        (env: {
          name = "${env} (tun)";
          url = "mysql://${workvars.demo-db-creds}@${env}-mysql8.demo:3307";
        })
        [
          "demo-px"
          "demo-al"
          "demo-vr"
        ];

    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
      matchBlocks = {
        "*" = {
          identityFile = "~/.ssh/lensa2";
        };

        "gitlab.${workvars.domain}" = {
          host = workvars.domain;
          identityFile = "~/.ssh/lensa2";
        };

        "natstaging" = {
          hostname = workvars.staging-ip;
          identityFile = "~/.ssh/lensa2";
        };

        "10.33.*" = {
          identityFile = "~/.ssh/new-staging2018.pem";
          user = "ec2-user";
          identitiesOnly = true;
          proxyCommand = "ssh natstaging -W %h:%p";
        };

        "graylog-staging-tunnel" = {
          user = "mihaly.papp";
          hostname = workvars.staging-ip;
          identityFile = "~/.ssh/lensa2";
          localForwards = [
            {
              bind.port = 9988;
              host.address = "10.33.3.181";
              host.port = 9000;
            }
          ];
        };
      };

    };
  };

  homebrew.casks = [
    "docker"
    "flux"
    "google-chrome"
    "fontlab"
  ];

  users.users.${vars.username}.home = "/Users/${vars.username}";

  system.stateVersion = 4;
}
