{ vars, ... }: {
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

    work = {
      enable = true;
      username = vars.username;
    };
  };

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";

    modules = { discord.enable = true; };
  };

  users.users.${vars.username}.home = "/Users/mihaly.papp";

  system.stateVersion = 4;
}

