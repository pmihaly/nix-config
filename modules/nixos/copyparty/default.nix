{
  pkgs,
  lib,
  config,
  vars,
  ...
}:
with lib;
let
  cfg = config.modules.copyparty;
  storage = vars.storage;
  package = pkgs.copyparty;
  copypartyExe = "${lib.getExe package}";

  # Two instances, two hand-rolled units. The 9001/copyparty flake NixOS
  # module is deliberately NOT used (its unit sandbox is incompatible with
  # this machine — see below); pkgs.copyparty from the flake overlay is
  # still used.
  #
  # The flake module sandboxes its unit with TemporaryFileSystem =
  # [ { directory = "/"; ... :ro } ] plus one read-only bind per volume. On
  # this machine (tmpfs root) that clobbers every bind it emits: the
  # service ends up in a namespace with an empty, read-only / and a
  # read-only /persist, so a volume at / (and any hist dir under /persist)
  # fails with EROFS and the instance starts with 0 volumes — the exact
  # failure the old instance suffered.
  #
  # Private instance: whole filesystem, tailnet-only (mkService firewall),
  # password auth, runs as root. No mount sandbox at all — it must see all
  # of /, and with root + password there is nothing to sandbox from.
  #
  # Public instance: a single directory (${storage}/Public), world
  # read/write, behind the public nginx vhost. Listens on loopback only
  # (nginx is its only client; port 3211 is not in the firewall, and the
  # NixOS firewall's default-drop keeps it closed even if that ever
  # changes). Runs as the unprivileged `copyparty` user; ProtectSystem=
  # full makes /usr /boot /etc read-only but leaves / and /persist
  # writable — NOT strict, which would make / read-only too.
  #
  # XDG_CONFIG_HOME points at a persistent, copyparty-owned dir
  # (${storage}/Services/copyparty-public): with home=/nonexistent
  # copyparty falls back to /tmp for its runtime state, hits its
  # untrusted-state failsafe (CRIT, sessions disabled) and refuses to
  # register the volume. The dir must exist before start, and the
  # unprivileged user cannot create it (its parent is root-owned), so
  # preStart creates both it and the volume root — the tmpfiles `d`
  # rules are the boot-time self-healing safety net only.

  # The private password is injected at startup by replace-secret from the
  # agenix materialized file, so it never lands in the Nix store or the
  # unit file (pattern from the copyparty flake module). A *password*
  # change does not restart the unit (the age secret is not a store path,
  # so it can't be a restart trigger) — after re-encrypting and deploying:
  # `systemctl restart copyparty-private`.
  privateConf = pkgs.writeText "copyparty-private.conf" ''
    [global]
    i: 0.0.0.0
    p: 3210
    no-reload

    [accounts]
    ${vars.username}: {{copyparty-private}}

    [/]
    /
    accs: 
    A: ${vars.username}
    flags: 
    d2t
    e2d
    fk: 4
    hist: ${storage}/Services/copyparty
    nohash: .iso$
    scan: 60
  '';

  # Anonymous rwmd (read/write/move/delete, no admin, no dotfiles).
  # Upload limits are OFF by default in copyparty, so they are set
  # explicitly: per-client maxn/maxb (burst abuse) and total volume caps
  # vmaxb/vmaxn, so a public share cannot fill the 250G /persist (100g cap
  # leaves headroom for everything else).
  #
  # e2d (embedded sqlite database) is REQUIRED, not optional: in
  # v1.20 a `d2t` volume without `e2d` is silently dropped at startup
  # (up2k logs "0 volumes", no CRIT, the server answers with its
  # zero-volume info page) — verified on this exact build. State
  # persists on /persist and survives reboots: the up2k db + upload-undo
  # history in <volume>/.hist/, and the sessions db in the XDG config
  # dir. (A share with no *visible* files shows copyparty's plain-text
  # info page even to browsers; the full Web UI appears once the first
  # file exists — cosmetic, by upstream design.)
  publicConf = pkgs.writeText "copyparty-public.conf" ''
    [global]
    i: 127.0.0.1
    p: 3211
    no-reload

    [/]
    ${storage}/Public
    accs: 
    rwmd: *
    flags: 
    d2t
    e2d
    maxb: 1g,300
    maxn: 250,600
    scan: 60
    vmaxb: 100g
    vmaxn: 100k
  '';
in
{
  options.modules.copyparty = {
    enable = mkEnableOption "copyparty (private tailnet instance + public share)";
  };

  config = mkIf cfg.enable (mkMerge [
    # --- user + self-healing persistent state ---------------------------
    # `d` rules re-create/repair ownership at every boot (and tmpfiles
    # --create), so a /persist rebuild or a stray chown cannot silently
    # strand the state. (`z` was tried first; on this machine it
    # silently no-ops even when the parent exists, so `d` is used.)
    {
      users.groups.copyparty = { };
      users.users.copyparty = {
        isSystemUser = true;
        group = "copyparty";
        home = "/nonexistent";
      };

      systemd.tmpfiles.rules = [
        "d ${storage}/Services/copyparty 0700 root root -"
        "d ${storage}/Public 0755 copyparty copyparty -"
        "d ${storage}/Services/copyparty-public 0700 copyparty copyparty -"
      ];
    }

    # --- private instance: tailnet-only on 3210, root, password auth ----
    {
      systemd.services.copyparty-private = {
        description = "Copyparty private (whole system, tailnet-only, password auth)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "local-fs.target"
        ];
        restartTriggers = [ privateConf ];
        preStart = ''
          install -m 600 ${privateConf} /run/copyparty-private/copyparty.conf
          ${pkgs.replace-secret}/bin/replace-secret '{{copyparty-private}}' ${
            config.age.secrets."server/copyparty-misi".path
          } /run/copyparty-private/copyparty.conf
          # Hist dir (deterministic; the tmpfiles `d` rule heals at boot).
          install -d -m 0700 ${storage}/Services/copyparty
        '';
        serviceConfig = {
          User = "root";
          NoNewPrivileges = true;
          ExecStart = "${copypartyExe} -c /run/copyparty-private/copyparty.conf";
          RuntimeDirectory = "copyparty-private";
          Restart = "on-failure";
        };
      };
    }

    # --- public instance: loopback-only behind nginx, unprivileged -----
    {
      systemd.services.copyparty-public = {
        description = "Copyparty public share (loopback-only, proxied by nginx)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "local-fs.target"
        ];
        restartTriggers = [ publicConf ];
        preStart = ''
          install -m 600 ${publicConf} /run/copyparty-public/copyparty.conf
          # The volume root and the XDG config dir must exist before
          # start: tmpfiles may run after this unit in mid-boot
          # activations, and the unprivileged user cannot create them
          # (both parents are root-owned).
          install -d -m 0755 -o copyparty -g copyparty ${storage}/Public
          install -d -m 0700 -o copyparty -g copyparty ${storage}/Services/copyparty-public
        '';
        serviceConfig = {
          User = "copyparty";
          Group = "copyparty";
          # Persistent config/keys; see the module header — the /tmp
          # fallback trips copyparty's untrusted-state failsafe.
          Environment = [ "XDG_CONFIG_HOME=${storage}/Services/copyparty-public" ];
          NoNewPrivileges = true;
          PrivateTmp = true;
          # `full` (ro /usr /boot /etc) — NOT `strict`, which would also
          # make / (and with it /persist) read-only.
          ProtectSystem = "full";
          ProtectHome = true;
          ExecStart = "${copypartyExe} -c /run/copyparty-public/copyparty.conf";
          RuntimeDirectory = "copyparty-public";
          Restart = "on-failure";
        };
      };
    }

    # --- private: tailnet vhost + firewall (3210) + dashboard ----------
    (mkService {
      subdomain = "copyparty";
      port = 3210;
      dashboard = {
        category = "Documents";
        name = "Copyparty";
        logo = ./copyparty.svg;
      };
      extraConfig = { };
    })

    # --- public: files.${publicDomainName} (nginx + Let's Encrypt) -----
    # Hand-rolled rather than mkService: mkService's tailnet base would add
    # /files → 301 http://<domain>:3211, but 3211 is loopback-only so that
    # redirect would be dead. Overriding that same location from
    # extraConfig is a hard conflict (two same-priority definitions of a
    # declared sub-option), and mkForce would win wholesale at the
    # virtualHosts level and clobber every other vhost. So: the public
    # vhost (forceSSL + ACME; the module auto-generates the 443 vhost, the
    # acme-challenge locations and the /var/lib/acme/<vhost>/ cert paths)
    # plus a tailnet-vhost /files location pointing at the public site.
    # No `default = true` — it-tools owns the apex default_server.
    {
      services.nginx.virtualHosts."files.${vars.publicDomainName}" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = "/var/lib/acme/acme-challenge";
        locations."/" = {
          proxyPass = "http://127.0.0.1:3211";
        };
      };

      # Same values it-tools' mkService contributes; duplicates merge
      # cleanly (equal scalars, concatenated lists).
      security.acme = {
        acceptTerms = true;
        defaults.email = vars.acmeEmail;
      };
      systemd.tmpfiles.rules = [
        "d /var/lib/acme/acme-challenge 0750 acme nginx -"
        "z /var/lib/acme/acme-challenge 0750 acme nginx -"
      ];

      # Tailnet: send /files to the public site (3211 is not reachable
      # from the tailnet).
      services.nginx.virtualHosts."${vars.domainName}".locations."/files" = {
        return = "301 https://files.${vars.publicDomainName}/";
      };

      modules.homer.services.Documents."Public Files" = {
        logo = ./copyparty.svg;
        url = "https://files.${vars.publicDomainName}";
      };
    }
  ]);
}
