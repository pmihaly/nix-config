{ pkgs, inputs, ... }: {
  home.stateVersion = "22.05";
  imports = [
    ./modules/home-manager
    inputs.agenix.homeManagerModules.default
    ./secrets/home-manager
  ];

  nixpkgs.overlays = import ./overlays;

  modules = let
    bookmarks = rec {
      h = "~";
      d = "~/Downloads";
      p = "~/personaldev";
      w = "~/lensadev";
      o = "~/Sync/org";
      n = "~/.nix-config";
      fio = p + "/finances/import/otp/in";
      fir = p + "/finances/import/revolut/in";
      fiw = p + "/finances/import/wise/in";
    };
  in {
    vscode.enable = true;
    firefox.enable = true;
    nvim.enable = true;
    git.enable = true;
    shell = {
      enable = true;
      inherit bookmarks;
    };
    mpv.enable = true;
    lf = {
      enable = true;
      inherit bookmarks;
    };
    kitty.enable = true;
    newsboat.enable = true;
    neomutt.enable = true;
    zathura.enable = true;
    discord.enable = true;
  };

  home.packages = let
    work = with pkgs; [
      awscli
      git-lfs
      saml2aws
      openssl
      obsidian
      jwt-cli
      libossp_uuid # uuid from cli
      slack
    ];
  in work ++ (with pkgs; [
    keepassxc
    syncthing
    act # running github actions locally
    nix-tree # visualisation of nix derivations
    keepass-diff # diffing .kdbx files
    inputs.img2theme.packages."${pkgs.system}".default
    inputs.agenix.packages."${pkgs.system}".default
    inputs.deploy-rs.packages."${pkgs.system}".default
    yt-dlp
  ]);
}
