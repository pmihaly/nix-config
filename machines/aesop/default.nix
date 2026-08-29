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
  # skylake auto-deploy (gitops)
  #
  # Deployment is push-based: hermes on skylake commits in the skylake
  # checkout and PUSHES to GitHub (ssh to github.com — her only ssh
  # channel, provisioned by herself via the hermes-github-ssh key). She
  # never ssh's to aesop. A systemd timer here watches the PUBLIC
  # pmihaly/nix-config repo; when the branch advances it fast-forwards a
  # dedicated deploy checkout (no auth, no keys anywhere on this path)
  # and runs scripts/deploy-skylake.sh — building on aesop and activating
  # skylake as root over ssh, like `make skylake`. The only credential is
  # the agenix secret server/skylake-activate-ssh (below), materialized
  # by aesop itself, so there is nothing to copy between machines and
  # nothing that can rot on this side. See scripts/skylake-auto-deploy.sh
  # and AGENTS.md "Deploying Skylake".
  users.groups."hermes-deploy" = { };
  users.users."hermes-deploy" = {
    isSystemUser = true;
    group = "hermes-deploy";
    # Real home (the deploy checkout lives under it) so ssh can pin
    # skylake's host key in ~/.ssh/known_hosts on first use — the
    # activation script creates the dir; createHome stays off so NixOS
    # doesn't pre-create an empty one. No ssh authorized keys: hermes
    # never connects here anymore.
    home = "/var/lib/hermes-deploy";
    createHome = false;
    shell = pkgs.bash;
  };

  # Tools the deploy path needs on the session PATH (deploy-rs is
  # otherwise only in misi's home packages). The script pins its own
  # PATH too, so this is belt-and-braces.
  environment.systemPackages = [
    pkgs.deploy-rs
    pkgs.git
    pkgs.openssh
    pkgs.util-linux # flock (skylake-auto-deploy)
  ];

  # The timer runs `deploy`/`nix build` via the nix daemon as
  # hermes-deploy; that user must be trusted for it (builds, stores,
  # flake eval).
  nix.settings.trusted-users = [ "hermes-deploy" ];

  # SSH key for the deploy-rs activation hop (root@skylake over the
  # tailnet). The original is the gitignored ~/.ssh/id_skylake_rescue on
  # this machine; hermes-deploy reads the agenix materialization instead
  # — no copies, no gitignored files under /var/lib, provisioned by
  # aesop itself at every boot.
  age.secrets."server/skylake-activate-ssh" = {
    file = ../../secrets/server/skylake-activate-ssh.age;
    owner = "hermes-deploy";
    group = "hermes-deploy";
    mode = "400";
  };

  # Dedicated deploy checkout, ff-only pulled from the public GitHub repo
  # by scripts/skylake-auto-deploy.sh (never force-pushed, never
  # rewritten). The activation script only creates it once and keeps the
  # origin pointing at GitHub for interactive use.
  system.activationScripts."hermes-deploy-repo" = {
    deps = [ "users" ];
    # No `path` attribute on activation scripts — pin the store git.
    text = ''
      # Home + .ssh so the first ssh (deploy-rs / nix copy) can pin
      # skylake's host key.
      mkdir -p /var/lib/hermes-deploy/.ssh
      chown -R hermes-deploy:hermes-deploy /var/lib/hermes-deploy
      chmod 700 /var/lib/hermes-deploy /var/lib/hermes-deploy/.ssh
      # The checkout itself (owned by hermes-deploy; the first fetch
      # happens on the first timer tick). Point origin at GitHub — the
      # timer fetches by URL regardless.
      if [ ! -d /var/lib/hermes-deploy/nix-config/.git ]; then
        ${pkgs.git}/bin/git init -q /var/lib/hermes-deploy/nix-config
        ${pkgs.git}/bin/git -C /var/lib/hermes-deploy/nix-config remote add origin https://github.com/pmihaly/nix-config
        chown -R hermes-deploy:hermes-deploy /var/lib/hermes-deploy/nix-config
      fi
      # Self-heal origin for checkouts created before the gitops switch.
      ${pkgs.git}/bin/git -C /var/lib/hermes-deploy/nix-config remote set-url origin https://github.com/pmihaly/nix-config 2>/dev/null || true
    '';
  };

  # Gitops driver: deploy when the watched branch advances. The script is
  # single-sourced from the repo (scripts/skylake-auto-deploy.sh) so the
  # timer and the checkout never drift.
  systemd.services."skylake-auto-deploy" = {
    description = "Deploy skylake when the GitHub branch advances (gitops)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "hermes-deploy";
      Group = "hermes-deploy";
      WorkingDirectory = "/var/lib/hermes-deploy/nix-config";
    };
    script = builtins.readFile ../../scripts/skylake-auto-deploy.sh;
  };
  systemd.timers."skylake-auto-deploy" = {
    description = "Periodic check for skylake deploys";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      RandomizedDelaySec = "5min";
      Persistent = true;
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
