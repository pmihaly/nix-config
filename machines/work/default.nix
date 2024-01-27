{ pkgs, vars, ... }: {
  imports = [ ../../use-cases ];

  modules = {
    nix = {
      enable = true;
      username = vars.username;
    };

    shell = {
      enable = true;
      username = vars.username;
      extraBookmarks = { w = "~/lensadev"; };
    };

    gui = {
      enable = true;
      username = vars.username;
    };
  };

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";

    modules = {
      discord.enable = true;
      vscode.enable = true;
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
    ];
  };

  homebrew.casks = [ "sequel-ace" "pycharm-ce" ];

  users.users.${vars.username}.home = "/Users/${vars.username}";

  system.stateVersion = 4;
}

