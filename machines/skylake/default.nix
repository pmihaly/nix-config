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

    # Public dashboard: the apex domain (skylake.mihaly.codes) serves this
    # second homer instance (container homer-public, :8081 behind nginx,
    # Let's Encrypt). Board links: it-tools + the public copyparty share
    # + ntfy.
    # The private instance (modules.homer via the server use-case) is
    # unchanged: tailnet root redirects to /homer (see the nginx module).
    homer.public = {
      enable = true;
      services = {
        Tools."IT Tools" = {
          logo = "${pkgs.it-tools}/lib/android-chrome-512x512.png";
          url = "https://it-tools.${vars.publicDomainName}";
        };
        Files."copyparty" = {
          logo = ../../modules/nixos/copyparty/copyparty.svg;
          url = "https://files.${vars.publicDomainName}";
        };
        Notifications."ntfy" = {
          logo = ../../modules/nixos/ntfy/ntfy.svg;
          url = "https://ntfy.${vars.publicDomainName}";
        };
        # Cross-link to the private (tailnet-only) board. Only resolvable
        # from the tailnet — visitors on the internet get a dead link, which
        # is intended.
        Dashboards."Private Dashboard" = {
          logo = ../../modules/nixos/homer/homer.svg;
          url = "http://${vars.domainName}/homer/";
        };
        Chat."Matrix" = {
          logo = ../../modules/nixos/matrix/matrix.svg;
          url = "https://matrix.${vars.publicDomainName}";
        };
      };
    };

    # Public Matrix homeserver (Conduit, Rust). Served at
    # https://matrix.skylake.mihaly.codes over the existing nginx 80/443
    # front (Let's Encrypt); federation uses the well-known delegation on
    # the same vhost, so no extra public port is opened. Data lives in
    # /var/lib/private/matrix-conduit (persisted below). See
    # modules/nixos/matrix/ and PUBLIC-ACCESS.md.
    matrix.enable = true;

    # Cross-link on the private (tailnet) board to the public board.
    # Everything else on the private board arrives via each service's
    # mkService `dashboard` self-registration; this static group is the
    # single entry that doesn't.
    homer.services = {
      Dashboards."Public Dashboard" = {
        logo = ../../modules/nixos/homer/homer.svg;
        url = "https://${vars.publicDomainName}/";
      };
    };

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

  # The hermes agent (system user `hermes`, modules.hermes-agent) edits
  # this repo's checkout at /home/misi/.nix-config. The checkout itself is
  # a plain git clone on the persistent /home (not Nix-managed); Nix
  # manages the group that owns it, hermes's membership in it, and the ACL
  # that lets hermes traverse the 0700 /home/misi. One-time on-disk steps
  # already applied (persist; survive rebuilds) — re-run
  # scripts/nixcfg-heal.sh after any pull/commit done by root or misi, who
  # would otherwise create files without the group write bit:
  #   chgrp -R nixcfg /home/misi/.nix-config
  #   chmod -R g+rwX /home/misi/.nix-config
  #   find /home/misi/.nix-config -type d -exec chmod g+s {} +
  #   git -C /home/misi/.nix-config config core.sharedRepository group
  users.groups.nixcfg = { };
  users.users.hermes.extraGroups = [
    "nixcfg"
    "systemd-journal"
  ];
  systemd.tmpfiles.rules = [
    # Traverse /home/misi without listing it, to reach .nix-config.
    # Column order is Type Path Mode User Group Age Argument — five dashes,
    # then the ACL (one dash short puts the ACL in the Age column).
    # m::x is explicit: without it the mask collapses to the file's group
    # bits (--- on this 0700 home), making the named entry ineffective.
    "a /home/misi - - - - u:hermes:x,m::x"
  ];

  # The rule above only runs at boot (systemd-tmpfiles-setup). In between,
  # the mask on /home/misi got zeroed — anything that re-chmods the 0700
  # home sets the group bits, which *are* the ACL mask once a named entry
  # exists — silently disabling the traversal grant until the next reboot.
  # Re-apply on every activation so `make skylake` heals it too. Idempotent.
  system.activationScripts.hermes-nixcfg-traversal.text = ''
    if [ -d /home/misi ]; then
      ${pkgs.acl}/bin/setfacl -m u:hermes:x,m::x /home/misi
    fi
  '';

  # Git refuses to operate on a repo owned by another user ("dubious
  # ownership"). The checkout is owned by misi but edited by the hermes
  # system user (and occasionally root), so whitelist it in the system
  # git config — safe.directory is only honored in system/global config.
  environment.etc."gitconfig".text = ''
    [safe]
        directory = /home/misi/.nix-config
  '';

  # ------------------------------------------------------------------
  # Hermes self-apply (the single root thing hermes can do).
  #
  # Hermes edits /home/misi/.nix-config and pushes to GitHub, but she
  # has no way to ACTIVATE her config on skylake (her service runs under
  # ProtectSystem=strict + no root). These two root oneshot services are
  # the apply path: hermes runs exactly one allowed sudo command, which
  # only STARTS the service — root then builds + activates the checkout
  # with nixos-rebuild. No arbitrary command, no shell, no raw
  # nixos-rebuild flags (defense-in-depth: she already writes the
  # checkout, so the real trust boundary is what she commits).
  #
  # Usage (as hermes, on skylake):
  #   git -C /home/misi/.nix-config pull --ff-only origin vibecode
  #   sudo /run/current-system/sw/bin/systemctl start hermes-config-apply.service
  # status/logs:  journalctl -u hermes-config-apply -n 200
  # rollback:     sudo /run/current-system/sw/bin/systemctl start hermes-config-apply-rollback.service
  systemd.services."hermes-config-apply" = {
    description = "Apply hermes' nix-config on skylake (nixos-rebuild switch)";
    serviceConfig.Type = "oneshot";
    # root by default; Path is declared via `path` below. Build runs on
    # skylake itself (same as a local `nixos-rebuild switch`).
    path = [
      pkgs.nixos-rebuild
      pkgs.git
      pkgs.coreutils
    ];
    script = ''
      cd /home/misi/.nix-config
      nixos-rebuild switch --flake . --hostname skylake
    '';
  };
  systemd.services."hermes-config-apply-rollback" = {
    description = "Roll back the last hermes nix-config apply";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.nixos-rebuild
      pkgs.coreutils
    ];
    # --rollback needs no flake/args: switches to the previous generation.
    script = ''
      nixos-rebuild switch --rollback
    '';
  };

  # The ONLY sudo hermes gets: passwordless start of those two fixed
  # services. Matching is on the canonicalized path (sudo resolves
  # symlinks), so hermes' `sudo systemctl start ...` (which resolves to
  # /run/current-system/sw/bin/systemctl) matches the rule.
  security.sudo.extraRules = [
    {
      users = [ "hermes" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start hermes-config-apply.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start hermes-config-apply-rollback.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

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
      # Conduit DB + media (systemd DynamicUser puts the StateDirectory
      # under /var/lib/private/matrix-conduit). tmpfs /var would lose all
      # rooms/users on every reboot without this.
      "/var/lib/private/matrix-conduit"
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
