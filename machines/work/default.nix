{ pkgs, vars, ... }:
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

    gui.enable = true;
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
  ];

  users.users.${vars.username}.home = "/Users/${vars.username}";

  system.stateVersion = 4;
}
