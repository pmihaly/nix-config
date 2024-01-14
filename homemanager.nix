{ pkgs, inputs, ... }: {
  home.stateVersion = "22.05";
  imports = [
    ./modules/home-manager
    inputs.agenix.homeManagerModules.default
    ./secrets/home-manager
  ];

  nixpkgs.overlays = import ./overlays;

  modules = {
    vscode.enable = true;
    firefox.enable = true;
    nvim.enable = true;
    git.enable = true;
    shell.enable = true;
    mpv.enable = true;
    lf.enable = true;
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
    ];
  in work ++ (with pkgs; [
    keepassxc
    slack
    lazydocker
    syncthing
    act # running github actions locally
    nix-tree # visualisation of nix derivations
    keepass-diff # diffing .kdbx files
    comic-code
    transmission
    anki-bin
    inputs.img2theme.packages."${pkgs.system}".default
    wally-cli # configuring moonlander keyboard
    inputs.agenix.packages."${pkgs.system}".default
    inputs.deploy-rs.packages."${pkgs.system}".default
    yt-dlp
  ]);
}
