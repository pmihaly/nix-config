{ pkgs, modulesPath, lib, ... }:
{
  imports = [ ../../modules/nixos "${modulesPath}/virtualisation/amazon-image.nix" ];
  nixpkgs.overlays = import ../../overlays;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.misi = {
    home.stateVersion = "22.05";
    imports = [ ../../modules ];

    modules = {
      nvim.enable = true;
      git.enable = true;
      shell.enable = true;
      lf.enable = true;
      newsboat.enable = true;
    };
  };

  modules = {
    nginx.enable = true;
    jellyfin.enable = true;
    homer.enable = true;
  };

  boot.loader.grub = {
    enable = true;
    device = lib.mkForce "/dev/nvme0n1";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking = {
    hostName = "skylake";
    dhcpcd.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [ 69 ];
    settings.PasswordAuthentication = false;
    hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    ];
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "hu_HU.UTF-8";
    LC_IDENTIFICATION = "hu_HU.UTF-8";
    LC_MEASUREMENT = "hu_HU.UTF-8";
    LC_MONETARY = "hu_HU.UTF-8";
    LC_NAME = "hu_HU.UTF-8";
    LC_NUMERIC = "hu_HU.UTF-8";
    LC_PAPER = "hu_HU.UTF-8";
    LC_TELEPHONE = "hu_HU.UTF-8";
    LC_TIME = "hu_HU.UTF-8";
  };

  users.users.misi = {
    isNormalUser = true;
    description = "misi";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
    ];
  };

  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
  };

  system.stateVersion = "23.05";
}
