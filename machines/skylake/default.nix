{ pkgs, config, lib, vars, ... }: {
  imports = [ ../../use-cases ./hardware.nix ];

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
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
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

  home-manager.users.${vars.username}.home.stateVersion = "22.05";

  users.mutableUsers = false;
  users.users.root.initialPassword = "root";
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
    initialPassword = vars.username;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking = {
    hostName = "skylake";
    interfaces.enp5s0.ipv4.addresses = [{
      address = "192.168.0.30";
      prefixLength = 24;
    }];
  };

  programs.fuse.userAllowOther = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/acme"
      "/var/lib/systemd/coredump"
      "/var/lib/authelia-skylake"
    ];
    files = [ "/etc/machine-id" ];
    users.${vars.username} = {
      files = [ ".local/share/zsh" ];
      directories = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        "Sync"
        "Maildir"
        "personaldev"
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".local/share/keyrings";
          mode = "0700";
        }
        ".mozilla"
        ".nix-config"
        ".steam"

        # minecraft
        ".cache/appimage-run"
        ".local/share/PolyMC"

        ".config/lutris"
        ".local/share/lutris"

        ".local/share/direnv"
        ".config/discord" # discord state
        ".local/share/newsboat"
        ".local/share/nvim"
      ];
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
