{ pkgs, lib, vars, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
    ../../modules/nixos
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "post-office";
  networking.domain = "";

  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [ 69 ];
    settings.PasswordAuthentication = false;
    hostKeys = [{
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
    ];
  };

  programs.zsh.enable = true;

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";
    imports = [ ../../modules ];

    modules = {
      nvim.enable = true;
      git.enable = true;
      shell.enable = true;
      lf.enable = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
  };
}
