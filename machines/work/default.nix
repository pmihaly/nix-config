{
  pkgs,
  vars,
  ...
}:
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

  ids.uids.nixbld = 300; # i dont want to update macos

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";

    modules = {
      vscode.enable = true;
      firefox.extraProfiles.work = {
        id = 1;
        name = "work";
        bookmarks =
          [
            {
              name = "jumpcloud";
              url = "https://console.jumpcloud.com";
            }
            {
              name = "jira";
              url = "https://lensainc.atlassian.net/browse/PHOENIX";
            }
            {
              name = "datadog";
              url = "https://app.datadoghq.com/dashboard";
            }
            {
              name = "prod graylog";
              url = "https://graylog.lensa.com";
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
          ++ builtins.concatMap
            (service: [
              {
                name = "${service} mr";
                url = "https://gitlab.lensa.com/lensa/phoenix/${service}/-/merge_requests";
              }
              {
                name = "${service} pipe";
                url = "https://gitlab.lensa.com/lensa/phoenix/${service}/-/pipelines";
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
    };

    programs.lazygit.settings.services = {
      "gsh.lensa.com" = "gitlab:gitlab.lensa.com";
    };

    programs.zsh.shellAliases = {
      d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
      dn = "d && nvim";
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
      bruno
    ];
  };

  homebrew.casks = [
    "docker"
    "sequel-ace"
    "tableplus"
    "pycharm-ce"
    "flux"
    "google-chrome"
  ];

  users.users.${vars.username}.home = "/Users/${vars.username}";

  system.stateVersion = 4;
}
