{
  pkgs,
  config,
  lib,
  vars,
  ...
}:
{
  imports = [
    ../../use-cases
    ./hardware.nix
  ];

  modules = {
    nix.enable = true;

    shell = {
      enable = true;
      extraBookmarks = {
        t = "${vars.persistDir}/opt/skylake-storage/Media/TV";
        y = "${vars.persistDir}/opt/skylake-storage/Media/TV/Youtube";
        m = "${vars.persistDir}/opt/skylake-storage/Media/Movies";
      };
      sshServer.hostKeys = [
        {
          path = "${vars.persistDir}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    server.enable = true;
    style.enable = true;
  };

  home-manager.users.${vars.username}.home.stateVersion = "22.05";

  users.mutableUsers = false;
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
    initialPassword = vars.username;
    hashedPasswordFile = "/persist/${vars.username}-password";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking = {
    hostName = "skylake";
    interfaces.enp5s0.ipv4.addresses = [
      {
        address = "192.168.0.30";
        prefixLength = 24;
      }
    ];
  };

  programs.fuse.userAllowOther = true;

  environment.persistence.${vars.persistDir} = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [ "/etc/machine-id" ];
    users.${vars.username} = {
      files = lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.files;
      directories = [
        "Sync"
      ] ++ lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.directories;
    };
  };

  time.timeZone = vars.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  system.stateVersion = "23.05";
}
