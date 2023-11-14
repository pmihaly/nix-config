{ pkgs, ... }:
{
  nixpkgs.overlays = import ../../overlays;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.misi = {
    home.stateVersion = "22.05";
    imports = [ ../../modules ];

    modules = {
      nvim.enable = false; # TODO: fails on aarch64
      git.enable = true;
      shell.enable = true;
      lf.enable = true;
      newsboat.enable = true;
    };

    home.packages = with pkgs; [
      docker-client
    ];
  };

  imports = [ ../../modules/nixos ];
  modules = {
    nginx.enable = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "skylab";
    dhcpcd.enable = true;
  };

  time.timeZone = "Europe/Budapest";
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
    extraGroups = [ "wheel" "podman" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  fonts.packages = [
    pkgs.iosevka-custom
  ];

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
  };

  virtualisation = {
    docker.enable = false;
    podman = {
      enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dnsEnabled = true;
    };
  };

  virtualisation.arion = {
    backend = "podman-socket";
  };

  system.stateVersion = "23.05";
}
