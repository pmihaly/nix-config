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
    ../../modules-v2/nixos
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

    backup = {
      enable = true;
      machineId = "skylake";
      include = [
        vars.storage
        vars.serviceConfig
        "${vars.storage}/Media/Pictures"
      ];
      exclude = [
        "${vars.storage}/Media/Downloads"
        "${vars.storage}/Media/TV"
        "${vars.storage}/Media/Movies"
        "${vars.storage}/Media/Audiobooks"
      ];
      timer = "hourly";
    };

    containers-gc = {
      enable = true;
      timer = "daily"; # prune unused podman images — 2026-08 /persist ENOSPC root cause
    };
  };

  home-manager.users.${vars.username}.home.stateVersion = "22.05";

  users.mutableUsers = false;

  # /root is NOT in the persistence list (only /home is), so /root/.ssh vanishes
  # on every boot (root = tmpfs). Declare the key here so it is recreated from
  # the store each activation. (2026-08-23: after the migration to the new
  # Hetzner server, root login was lost until this was added.)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE82BvyY3AfskGM3QlHEpjG7N6FomVAI21MbkilGBOHC misi@aesop"
  ];

  # SSH is tailnet-only. Two things used to expose 22 to any source: the
  # shell use-case's `openFirewall = true`, and (until 2026-08) the nginx
  # module's allowedTCPPorts. On a VPS neither may stand, so kill the former
  # and allow 22 from tailscale0 only. tailnetRules emits rules for both
  # firewall backends (the active backend uses its own, the other is inert),
  # same pattern as mkService.
  services.openssh.openFirewall = lib.mkForce false; # plain def in shell use-case conflicts
  networking.firewall = lib.tailnetRules [ 22 ];

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
    password = vars.username;
  };

  boot.loader.grub.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;


  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "skylake";

  programs.fuse.userAllowOther = true;

  environment.persistence.${vars.persistDir} = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      # ACME: Let's Encrypt account keys + issued certs + challenge webroot.
      # Without this, every reboot would re-register the LE account and
      # re-order certificates (rate limits!), and nginx would serve the
      # minica self-signed bootstrap cert again.
      "/var/lib/acme"
    ];
    files = [ "/etc/machine-id" ];
    users.${vars.username} = {
      files = lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.files;
      directories = [
        "Sync"
      ]
      ++ lib.lists.unique config.home-manager.users.${vars.username}.modules.persistence.directories;
    };
  };

  # Hetzner cx23 (2 vCPU / 4 GB, downsized from cpx42 2026-10): steady-state usage
  # (~4 GB with immich ML indexing peaks) can exceed RAM, so keep an
  # 8 GB swapfile on /persist. btrfs: NixOS's mkswap unit uses `btrfs filesystem
  # mkswapfile` (handles nodatacow) when the file doesn't exist yet.
  swapDevices = [
    {
      device = "/persist/swapfile";
      size = 8192; # MiB
    }
  ];

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
