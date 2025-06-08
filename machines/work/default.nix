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
    "demo-px"
    "demo-al"
    "demo-vr"
    "demo-am2"
    "demo-fp2"
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
        w = "~/lensadev";
      };
    };

    gui = {
      enable = true;
      terminal-font-size = "14.0";
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
      bookmarks.settings =
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
              "kokoro-fastapi"
            ];
    };

    programs.lazygit.settings.services = {
      "gsh.${workvars.domain}" = "gitlab:gitlab.${workvars.domain}";
    };

    home.packages =
      with pkgs;
      [
        awscli
        git-lfs
        saml2aws
        openssl
        obsidian
        jwt-cli
        slack
        gnumake
        mariadb # vim dadbod
        jetbrains.pycharm-community-bin
        aegisub
        (pkgs.writers.writePython3Bin "json-to-pq" { libraries = [ pkgs.python3Packages.polars ]; } ''
          import sys
          import polars as pl
          from io import BytesIO

          df = pl.read_json(sys.stdin.buffer.read())

          buf = BytesIO()
          df.write_parquet(buf)
          sys.stdout.buffer.write(buf.getvalue())
        '')
        (pkgs.writers.writePython3Bin "pq-to-json" { libraries = [ pkgs.python3Packages.polars ]; } ''
          import sys
          import polars as pl
          from io import BytesIO

          df = pl.read_parquet(sys.stdin.buffer.read())

          buf = BytesIO()
          df.write_json(buf)
          sys.stdout.buffer.write(buf.getvalue())
        '')
      ]
      ++ (concatMap (
        env:
        let
          envId = env |> splitString "-" |> lists.last;
        in
        [
          (pkgs.writeShellScriptBin "trget-${envId}" "${getExe' pkgs.httpie "http"} get http://tracing-system-app.${env}.lms/api/v1/business-process/$1")
          (pkgs.writeShellScriptBin "trparent-${envId}" "${getExe pkgs.jq} -r .parent_global_trace_id | xargs -I{} ${getExe' pkgs.httpie "http"} get http://tracing-system-app.${env}.lms/api/v1/business-process/{}")
          (pkgs.writeShellScriptBin "trcreate-${envId}" ''${getExe pkgs.jq} '{"source": "misi_lol", "global_state": .}' | ${getExe' pkgs.httpie "http"} post http://tracing-system-app.${env}.lms/api/v1/business-process/$1/v1 | ${getExe pkgs.jq} '.global_trace_id' -r | xargs -I{} trget-${envId} {}'')
          (pkgs.writeScriptBin "dlvid-${envId}" ''
            #! ${getExe pkgs.nushell}
            def main [
              vid: string # video id
            ]: nothing -> bool {
              {filters: [{video_id: $vid}]}
              | to json
              | http post http://video-streamer.${env}.lms/v1/get-video-playback-details
              | get ([$vid, "playback_url"] | into cell-path)
              | ${getExe pkgs.yt-dlp} $in -o $"($vid).mp4"
              }
          '')
          (pkgs.writeShellScriptBin "dump-${envId}" "${getExe' pkgs.mariadb "mysqldump"} --user=${workvars.demo-db-user} --password=${workvars.demo-db-password} --host=${env}-mysql8.demo --port=3307 $1")
        ]
      ) envs);

    programs.nushell.extraConfig = ''
      def --env d [] { ls ${modules.shell.extraBookmarks.w} | where type == "dir" | par-each {{path: $in.name, name: ($in.name | split row "/" | last)}} | input list --fuzzy --display name | cd $in.path }
      def --env dn [] { p ; nvim }

      def "from pq" [] { pq-to-json | from json }
      def "to pq" [] { to json | json-to-pq }

      def unlockpdf [password: string, filename: string] { ${getExe pkgs.qpdf} --password=$password --decrypt $filename $"unlocked_($filename)" }

      def ticket [] { git branch --show-current | split words | take 2 | str join "-" }
      def jira [] { ticket | start $"${workvars.jira-url}/($in)" }

      def db [] { mkdir ~/db; cd ~/db; nvim -c DBUI }
      def docker-prune [] { docker system prune --all --force --volumes }
    '';

    programs.nixvim = {
      keymaps = [
        {
          mode = [
            "n"
          ];
          key = "<leader>mf";
          action = ":make flint<cr>";
        }
      ];

      globals.dbs =
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
        ++ map (env: {
          name = "${env} (tun)";
          url = "mysql://${workvars.demo-db-user}:${workvars.demo-db-password}@${env}-mysql8.demo:3307";
        }) envs;
    };

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

        natstaging = {
          hostname = workvars.ips.staging;
          identityFile = "~/.ssh/lensa2";
        };

        "${workvars.ips.natstaging-range}" = {
          identityFile = "~/.ssh/new-staging2018.pem";
          user = workvars.natstaging-user;
          identitiesOnly = true;
          proxyCommand = "ssh natstaging -W %h:%p";
        };

        graylog-staging-tunnel = {
          user = "mihaly.papp";
          hostname = workvars.ips.staging;
          identityFile = "~/.ssh/lensa2";
          localForwards = [
            {
              bind.port = 9988;
              host.address = workvars.ips.staging-graylog;
              host.port = 9000;
            }
          ];
        };

        demo-px = {
          user = workvars.natstaging-user;
          hostname = workvars.ips.demo-px;
          identitiesOnly = true;
          identityFile = "~/.ssh/new-staging2018.pem";
          proxyCommand = "ssh natstaging -W %h:%p";
          setEnv = {
            TERM = "xterm";
          };

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
  system.primaryUser = vars.username;

  system.stateVersion = 5;
}
