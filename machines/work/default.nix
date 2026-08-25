{
  pkgs,
  vars,
  lib,
  inputs,
  ...
}:
with lib;
let
  workvars = fromTOML (
    builtins.readFile "/Users/${vars.username}/.nix-config/machines/work/workvars.toml"
  );
  envs = [
  ];
  # Installed by caveman's own installer, not managed by nix.
  claudeHooks = "/Users/${vars.username}/.claude/hooks";
in
{
  imports = [ ../../use-cases ];

  modules = {
    nix.enable = true;

    shell = {
      enable = true;
      extraBookmarks = {
        su = "'~/Library/Application\ Support'";
        w = "~/work";
      };
      extraAliases = {
        d = ''cd "$(for w in ~/work/*/branches/*/.git ~/work/*/branches/*/*/.git; do [ -e "$w" ] && dirname "$w"; done | fzf)"'';
        j = ''open "https://fareharbor.atlassian.net/browse/$(git branch --show-current | grep -Po "[A-Z]{3}-[0-9]*")"'';
        mf = "make format";
	g = ''open "https://gitlab.com/$(git remote get-url origin | sed -E "s|.*gitlab.com[:/]||; s|\.git$||")/-/merge_requests?scope=all&search=$(git branch --show-current | grep -Po "[A-Z]{3}-[0-9]*")"'';
};
      extraEnv = {
   "CFLAGS"="-I${pkgs.openssl}/include";
   "LDFLAGS"="-L${pkgs.openssl}/lib";
      }
      // workvars.extra-env;
    };

    gui = {
      enable = true;
      terminal-font-size = "14.0";
    };
  };

  ids.uids.nixbld = 350;

  environment.etc."hosts".text = ''
    127.0.0.1 local.fhbr.co
    127.0.0.2 hschk.co
    127.0.0.3 hseas.co
    127.0.0.1 localhost
    255.255.255.255 broadcasthost
    ::1 localhost
   '';

  home-manager.backupFileExtension = "backup";
  home-manager.overwriteBackup = true;
  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";

    modules = {
      vscode.enable = true;
      git.name = "Mihaly Papp";
      git.email = workvars.email;
    };

    xdg.configFile."tridactyl/tridactylrc".text = ''
      set searchurls.j  https://fareharbor.atlassian.net/browse/
    '';
    programs.firefox.profiles.misi = {
      # Global defaults kill WebRTC for privacy; work needs it for Meet.
      # extraConfig text is appended after the shared defaults' extraConfig,
      # so these user_pref calls run later and win.
      extraConfig = lib.mkAfter ''
        user_pref("media.navigator.enabled", true);
        user_pref("media.peerconnection.enabled", true);
      '';
      bookmarks.settings = [
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
      google-chrome
      slack
      mariadb # vim dadbod
      nodejs_26
      poetry
      redis
      graphify
      inputs.boxes.packages.${pkgs.stdenv.hostPlatform.system}.default
      dbeaver-bin
      teleport
      glab
    ];

    programs.claude-code = {
      enable = true;
      rules = {
          code-style = ''
          - Follow existing conventions. Write the simplest code possible. No new symbols unless required.
          - Keep interfaces small; push complexity to implementation. Few deep methods over many shallow ones.
          - Provide sensible defaults so parameters disappear for the common case.
          - Vertical slices by business terms. 
	  - *very important* Max 2 level of nesting. function -> `for` -> `if` allowed, any deeper is not (except context managers in some cases)
	  - No `else` — use early returns.
	  - Immutable by default.
	  - No comments.
	  - Always write type hints
	  '';
          api-design = ''
          - Make illegal states unrepresentable. Prefer total functions and idempotent operations.
          - Use types to eliminate invalid states at compile time. Absorb rare cases into the common case.
          - Hide implementation details. Name for meaning, not mechanism. Question every parameter.
          - First design errors out of existence. If unavoidable, handle explicitly and visibly.
          - Fail loudly with context. Never swallow errors without logging.
	  '';
      };
      settings = {
        permissions.defaultMode = "auto";

        # home-manager owns ~/.claude/settings.json, so anything written there
        # by an installer is wiped on the next switch. Caveman registers itself
        # that way, hence declaring it here instead.
        hooks = {
          SessionStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = ''"${pkgs.nodejs_26}/bin/node" "${claudeHooks}/caveman-activate.js"'';
                  timeout = 5;
                  statusMessage = "Loading caveman mode...";
                }
              ];
            }
          ];
          UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = ''"${pkgs.nodejs_26}/bin/node" "${claudeHooks}/caveman-mode-tracker.js"'';
                  timeout = 5;
                  statusMessage = "Tracking caveman mode...";
                }
              ];
            }
          ];
        };

        statusLine = {
          type = "command";
          command = ''${pkgs.bash}/bin/bash "${claudeHooks}/caveman-statusline.sh"'';
        };
      };
    };

    programs.herdr = {
      enable = true;
      settings = {
        ui = {
	  sound.enabled = false;
	  toast.delivery = "system";
	};
      };
    };

    programs.bash = {
      bashrcExtra = "source ~/.profile";

      # the nixos programs.bash.promptInit default, which darwin lacks
      initExtra = ''
        # Provide a nice prompt if the terminal supports it.
        if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
          PROMPT_COLOR="1;31m"
          ((UID)) && PROMPT_COLOR="1;32m"
          if [ -n "$INSIDE_EMACS" ]; then
            # Emacs term mode doesn't support xterm title escape sequence (\e]0;)
            PS1="\n\[\033[$PROMPT_COLOR\][\u@\h:\w]\\$\[\033[0m\] "
          else
            PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
          fi
          if test "$TERM" = "xterm"; then
            PS1="\[\033]2;\h:\u:\w\007\]$PS1"
          fi
        fi
      '';
    };

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

    environment.pathsToLink = ["/lib"];
    services.postgresql = {
      enable = true;
      enableTCPIP = true;
      package = pkgs.postgresql_18;
    };


  homebrew.casks = [
    "docker-desktop"
    "flux-app"
  ];

  users.users.${vars.username} = {
    home = "/Users/${vars.username}";
    uid = 501; # required because users.knownUsers includes this user
  };
  system.primaryUser = vars.username;

  system.stateVersion = 5;
}
