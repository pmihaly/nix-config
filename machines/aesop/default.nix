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
    nginx.enable = true;
    homer.enable = true;
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
      browser-hintchars = "fjdksla;";
      terminal-font-size = "13.0";
    };
    gaming.enable = true;
    music-production.enable = true;
    dev.enable = true;

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

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";
    programs.firefox.profiles.misi.bookmarks.settings = [
      {
        name = "terraria progression graph";
        url = "https://terraria.fandom.com/wiki/Guide:Game_progression_graph";
      }
    ];

    services.mpris-proxy.enable = true; # enable bluetooth headphone controls
  };

  users.mutableUsers = false;
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [
      "wheel"
      "video"
      "render"
    ];
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
      "/var/lib/bluetooth"
    ];
    files = [ ];
    users.${vars.username} = {
      files = lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.files;
      directories = [
        "Sync"
      ]
      ++ lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.directories;
    };
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pulseaudio.package = pkgs.pulseaudioFull; # extra bluetooth codecs

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "esc";
          leftcontrol = "leftalt";
          leftalt = "leftcontrol";
        };
      };
    };
  };

  # ------------------------------------------------------------------
  # hermes -> skylake deploy path
  #
  # hermes on skylake deploys skylake by ssh'ing here as hermes-deploy.
  # Every connection with that key runs scripts/hermes-deploy.sh as a
  # forced command (no shell, no other commands, no forwarding): it
  # fast-forwards a dedicated deploy checkout from the skylake checkout
  # and runs scripts/deploy-skylake.sh — building on aesop and
  # activating skylake remotely, exactly like `make skylake`.
  # See AGENTS.md "Deploying Skylake".
  users.groups."hermes-deploy" = { };
  users.users."hermes-deploy" = {
    isSystemUser = true;
    group = "hermes-deploy";
    home = "/nonexistent";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      # restrict = no-pty, no agent/port/X11 forwarding, no rhosts.
      # command= forces the deploy script regardless of what is requested.
      "restrict,command=\"/home/misi/.nix-config/scripts/hermes-deploy.sh\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKUB8cq8NYHwWjMZVB+PYsH5uok54fEc5M/M7eMNhZ9A hermes@skylake"
    ];
  };

  # Tools the deploy script needs on the session PATH (deploy-rs is
  # otherwise only in misi's home packages). The script pins its own
  # PATH too, so this is belt-and-braces.
  environment.systemPackages = [
    pkgs.deploy-rs
    pkgs.git
    pkgs.openssh
  ];

  # hermes-deploy must read two files inside the 0700 home without being
  # able to list it (or .ssh): the gitignored sudo password and the
  # id_skylake_rescue key. Both are chgrp'd to hermes-deploy + 640
  # (one-time on-disk steps below, files persist); the ACLs grant traverse
  # only, re-applied on every activation (the mask on a 0700 home
  # collapses to --- whenever the home is re-chmod'ed).
  systemd.tmpfiles.rules = [
    "a /home/misi - - - - u:hermes-deploy:x,m::x"
    "a /home/misi/.ssh - - - - u:hermes-deploy:x,m::x"
  ];
  system.activationScripts."hermes-deploy-traversal".text = ''
    ${pkgs.acl}/bin/setfacl -m u:hermes-deploy:x,m::x /home/misi
    ${pkgs.acl}/bin/setfacl -m u:hermes-deploy:x,m::x /home/misi/.ssh
  '';

  # One-time on-disk steps (misi-owned files; persist across rebuilds).
  # Run after this config is first activated (the group must exist):
  #   chgrp hermes-deploy /home/misi/.nix-config/machines/skylake/sudo-password
  #   chmod 640 /home/misi/.nix-config/machines/skylake/sudo-password
  #   chgrp hermes-deploy /home/misi/.ssh/id_skylake_rescue
  #   chmod 640 /home/misi/.ssh/id_skylake_rescue

  # Dedicated deploy checkout, ff-only synced from the skylake checkout
  # by scripts/hermes-deploy.sh (never force-pushed, never rewritten).
  system.activationScripts."hermes-deploy-repo" = {
    deps = [ "users" ];
    # No `path` attribute on activation scripts — pin the store git.
    text = ''
      mkdir -p /var/lib/hermes-deploy
      chown hermes-deploy:hermes-deploy /var/lib/hermes-deploy
      chmod 700 /var/lib/hermes-deploy
      if [ ! -d /var/lib/hermes-deploy/nix-config/.git ]; then
        ${pkgs.git}/bin/git init -q /var/lib/hermes-deploy/nix-config
        ${pkgs.git}/bin/git -C /var/lib/hermes-deploy/nix-config remote add origin ssh://misi@100.69.8.15/home/misi/.nix-config
      fi
    '';
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
