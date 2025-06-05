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
    ../../modules/nixos
    ../../modules-v2/nixos
    ./hardware.nix
  ];

  modules = {
    nix.enable = true;
    shell = {
      enable = true;
      extraBookmarks = { };
      sshServer.hostKeys = [
        {
          path = "${vars.persistDir}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
    gui = {
      enable = true;
      browser-hintchars = "tnseriao";
      terminal-font-size = "13.0";
    };
    gaming.enable = true;
    music-production.enable = true;
    dev.enable = true;
    style.enable = true;

    backup = with config.home-manager.users.${vars.username}; {
      enable = true;
      machineId = "aesop";
      include = [
        xdg.dataHome
        xdg.stateHome
        xdg.userDirs.music
        xdg.userDirs.pictures
        xdg.userDirs.videos
        "${home.homeDirectory}/personaldev"
      ];
      exclude = [
        "${xdg.dataHome}/Steam"
      ];
      timer = "hourly";
    };
  };

  home-manager.users.${vars.username}.home.stateVersion = "22.05";

  users.mutableUsers = false;
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [
      "wheel"
      "video"
      "render"
    ];
    initialPassword = vars.username;
    hashedPasswordFile = "${vars.persistDir}/${vars.username}-password";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking = {
    hostName = "aesop";
    interfaces.enp9s0.ipv4.addresses = [
      {
        address = "192.168.0.35";
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
    files = [ ];
    users.${vars.username} = {
      files = lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.files;
      directories = [
        "Sync"
      ] ++ lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.directories;
    };
  };

  systemd.tmpfiles.rules = [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];

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

  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "weekly";
    configs = {
      persist = {
        SUBVOLUME = "/persist";
        ALLOW_USERS = [ vars.username ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/persist" ];
  };

  system.stateVersion = "23.05";
}
