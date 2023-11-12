{ pkgs, customflakes, ... }:
{
  home.stateVersion = "22.05";

  nixpkgs.overlays = import ./overlays;

  imports = [ ./modules ];

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
  };

  home.packages =
    let
      work = with pkgs; [
        awscli
        git-lfs
        saml2aws
        openssl
        obsidian
        jwt-cli
        libossp_uuid # uuid from cli
      ];
    in
    work ++ (with pkgs; [
      keepassxc
      slack
      lazydocker
      syncthing
      act # running github actions locally
      discord
      nix-tree # visualisation of nix derivations
      keepass-diff # diffing .kdbx files
      iosevka-custom
      nerdfonts-fira-code
      zathura # pdf reader
      transmission
      anki-bin
    ])
    ++ (with customflakes; [
      img2theme.packages."${pkgs.system}".default
    ]);
}
