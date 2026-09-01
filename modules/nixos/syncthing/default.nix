{
  lib,
  pkgs,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.syncthing;

  # Syncthing's own state (config.xml + device cert/key + folder DB)
  # payload. Lives under ${vars.storage}/Services (not the services dir):
  # ${vars.storage} is in the restic include list (see the `backup` module
  # set in machines/skylake/default.nix), so the state is both persisted
  # and backed up -- while ${vars.serviceConfig} (config-only, operator
  # doesn't want it backed up) does NOT hold it.
  dataDir = "${vars.storage}/Services/syncthing";

  # Web GUI port (tailnet-only, fronted by the nginx redirect at /syncthing).
  guiPort = 8384;
in
{
  options.modules.syncthing = {
    enable = mkEnableOption "Syncthing (self-hosted file sync)";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      # Run as the machine owner: the historic datadir (and its 600-mode
      # config.xml/certs) is owned by ${vars.username}, and the sync folder
      # destinations share his UID. A dedicated `syncthing` system user
      # would have to chown an existing state -- avoid that.
      user = vars.username;
      # misi's primary group is "users"; there is NO group named after the
      # user (so User=misi:Group=misi fails at runtime -- systemd can't resolve
      # Group "misi"). The datadir is group multimedia (997, assigned to misi
      # in the server use-case), so run as that group to match ownership.
      group = "multimedia";

      # The datadir uses the legacy flat layout (config + db + keys all in
      # one dir) rather than the post-19.03 ${dataDir}/.config/syncthing
      # split. Match it explicitly so an existing install keeps its identity.
      inherit dataDir;
      configDir = dataDir;
      databaseDir = dataDir;

      # Gui bound to all interfaces so the nginx redirect (and any tailnet
      # device) can reach it;the WAN cannot (firewall rule below).
      guiAddress = "0.0.0.0:${builtins.toString guiPort}";

      # NixOS's openDefaultPorts would open 22000/tcp+udp and 21027/udp to
      # ANY source -- which violates the tailnet-only policy and would trip the
      # tailnetRules guard in lib/nixos/default.nix (a port can't be in both
      # allowedTCPPorts and a tailnet rule)? Firewall explicitly below instead.

      openDefaultPorts = false;
    };

    # Create the datadir if missing (purged datadir, fresh node). No `z`
    # heal: forcing ownership on an existing install would claim files the
    # operator may have chowned differently (e.g. a service user).
    # Group is `multimedia`, NOT ${vars.username}: there is no group named
    # after misi (primary group is "users"), so `0700 misi misi` would make
    # systemd-tmpfiles fail on the group. multimedia is the group the
    # service runs as, so it owns the datadir too.
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0700 ${vars.username} multimedia -"
      # The sync FOLDER root (the actual share, configured inside Syncthing
      # for the "Sync" folder) lives directly under ${vars.storage} -- NOT
      # under Services/. The parent /persist/opt/skylake-storage is
      # root-owned, so the service (running as misi) cannot mkdir it itself:
      # it must exist before syncthing starts. Create it as misi:multimedia.
      # Mode 0770: owner (misi) and group (multimedia) rwx. hermes is in the
      # multimedia group, so it can read/write the synced files. Also under
      # ${vars.storage}, so it is already covered by the restic include.
      "d ${vars.storage}/syncthing 0770 ${vars.username} multimedia -"
    ];

    # Named-user ACL so the hermes service user can read/write the synced
    # folder -- immediate (per-process), no agent restart needed. Group
    # membership alone only takes effect at process spawn, and the
    # already-running hermes agent wouldn't pick up `multimedia` until a
    # restart. (`z` tmpfiles rules don't accept ACL args -- systemd ignores
    # them -- so use setfacl, this repo's proven pattern for the same problem.
    # Also set a DEFAULT ACL so newly synced files (created as
    # misi:multimedia at umask 022) still inherit read/write for the
    # multimedia group -> hermes.
    system.activationScripts.hermes-syncthing-acl.text = ''
      if [ -d ${vars.storage}/syncthing ]; then
        ${pkgs.acl}/bin/setfacl -m u:hermes:rwX,d:g:multimedia:rwX,d:u:hermes:rwX,d:m::rwx,m::rwx ${vars.storage}/syncthing
      fi
    '';

    # One-time migration from the old datadir location
    # (${vars.serviceConfig}/syncthing) into the new storage path. Runs as
    # root before syncthing starts on the first boot after this change;
    # moves the existing config.xml + certs + folder DB across, so the
    # device keeps its identity and peers don't need re-adding. A fresh
    # install (no old datadir) is a no-op, and once migrated it never runs
    # again (old dir is gone).
    systemd.services.syncthing-migrate = {
      description = "Migrate syncthing datadir to ${vars.storage}/Services (one-time)";
      wantedBy = [ "syncthing.service" ];
      before = [ "syncthing.service" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        old=${vars.serviceConfig}/syncthing
        new=${dataDir}
        if [ -d "$old" ] && [ ! -e "$new/config.xml" ]; then
          echo "migrating $old -> $new"
          shopt -s dotglob
          mv "$old/"* "$new/"
          chown -R ${vars.username}:multimedia "$new"
          chmod 0700 "$new"
          echo "migrated ${dataDir}"
        fi
      '';
    };

    # Tailnet-only reachability. skylake's WAN input policy is default-DROP;
    # only the tailscale interface may reach these ports. Mirrors the
    # `tailnetRules` helper (lib/nixos/default.nix) but emits the UDP rules the
    # helper doesn't produce. (The helper's TCP rule and the `a port must not
    # be in allowedTCPPorts` guard is documentedin lib;openDefaultPorts
    # is off above so no conflict.)
    networking.firewall = {
      extraCommands = lib.concatStringsSep "\n" [
        "ip46tables -A nixos-fw -i tailscale0 -p tcp --dport ${builtins.toString guiPort} -j nixos-fw-accept"
        "ip46tables -A nixos-fw -i tailscale0 -p tcp --dport 22000 -j nixos-fw-accept"
        "ip46tables -A nixos-fw -i tailscale0 -p udp --dport 22000 -j nixos-fw-accept"
        "ip46tables -A nixos-fw -i tailscale0 -p udp --dport 21027 -j nixos-fw-accept"
      ];
      extraInputRules = lib.concatStringsSep "\n" [
        "iifname \"tailscale0\" tcp dport { ${builtins.toString guiPort} 22000 } accept"
        "iifname \"tailscale0\" udp dport { 22000 21027 } accept"
      ];
    };

    # GUI reachable at http://${vars.domainName}/syncthing (tailnet only);
    # nginx 301s the browser to the :8384 GUI on the tailnet. Same redirect
    # mkService (lib/nixos/default.nix) puts in place for internal services.

    services.nginx.virtualHosts."${vars.domainName}".locations."/syncthing" = {
      return = "301 http://${vars.domainName}:${builtins.toString guiPort}";
    };

    # Register a card on the Homer dashboard. Services normally self-register
    # via mkService's `dashboard` attr; syncthing defines its service directly
    # (no mkService), so register the card here to keep the board populated.
    # The GUI is the only reachable surface (tailnet-only firewall).
    modules.homer.services."Files"."Syncthing" = {
      logo = "${pkgs.syncthing}/share/icons/hicolor/512x512/apps/syncthing.png";
      url = "http://${vars.domainName}:${builtins.toString guiPort}";
    };
  };
}
