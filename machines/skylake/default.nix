{ pkgs, lib, vars, ... }: {
  imports = [ ../../use-cases ./hardware.nix ];

  home-manager.users.${vars.username}.home.stateVersion = "22.05";

  modules = {

    nix = {
      enable = true;
      username = vars.username;
    };

    shell = {
      enable = true;
      username = vars.username;
      extraBookmarks = {
        t = "/persist/opt/skylake-storage/Media/TV";
        m = "/persist/opt/skylake-storage/Media/Movies";
      };
      sshServer.hostKeys = [{
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }];
    };

    gui = {
      enable = true;
      username = vars.username;
    };

    server = {
      enable = true;
      username = vars.username;
    };

    gaming = {
      enable = true;
      username = vars.username;
    };

  };

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking = {
    hostName = "skylake";
    dhcpcd.enable = true;
  };

  time.timeZone = vars.timeZone;
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

  system.stateVersion = "23.05";
}
