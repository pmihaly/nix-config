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

  # Video tracks: pkgs.copyparty on this machine is the PATCHED build
  # (modules/nixos/copyparty/overlay.nix shadows the upstream flake
  # overlay; the patch adds ?th=json|mp4|vtt:K conversion endpoints, see
  # patches/video-tracks.patch). The client side is a self-contained
  # vanilla-JS plugin (video-tracks.js) served from a read-only [/plug]
  # volume (a store dir, so anonymous users on the public instance can
  # never modify it) and injected into every file-browser page via
  # --js-browser (the URL is nonce-wrapped by copyparty's template).
  #
  # Every volume gets an explicit `hist:` — copyparty forbids two
  # volumes sharing one hist dir, and a volume whose default
  # <vol>/.hist sits inside a read-only store dir would fail to create
  # it. The public instance's main hist is additionally moved OUT of
  # the anonymously-writable volume on purpose: with rwmd, any visitor
  # could overwrite <vol>/.hist/vr/*.json (cache of track metadata that
  # the plugin JSON.parses and renders) — cache poisoning = XSS. Outside
  # the volume (copyparty-owned 0700 dir) it is unreachable via HTTP.

  # Read-only volume dir that serves the plugin. The store path changes
  # when video-tracks.js changes → the confs (which embed it) change →
  # restartTriggers restarts both units.
  plugDir = pkgs.runCommand "copyparty-video-tracks" { } ''
    mkdir -p $out
    cp ${./video-tracks.js} $out/video-tracks.js
  '';

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
    js-browser: /plug/video-tracks.js

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

    [/plug]
    ${plugDir}
    accs: 
    r: *
    flags: 
    hist: ${storage}/Services/copyparty-plug
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
    js-browser: /plug/video-tracks.js

    [/]
    ${storage}/Public
    accs: 
    rwmd: *
    flags: 
    d2t
    e2d
    maxb: 10g,300
    maxn: 250,600
    scan: 60
    vmaxb: 100g
    vmaxn: 100k
    # Kept OUT of the rwmd volume: see the header comment (cache
    # poisoning = XSS).
    hist: ${storage}/Services/copyparty-public-hist

    [/plug]
    ${plugDir}
    # g = get: downloadable by exact URL (the js-browser script tag
    # /plug/video-tracks.js needs), but NOT listable — the volume stays
    # out of the public file browser. r would expose the directory tree.
    accs:
    g: *
    flags:
    hist: ${storage}/Services/copyparty-public-plug

    [/drop]
    ${storage}/Drop
    accs:
    w: *
    flags:
    d2t
    e2d
    maxb: 10g,300
    maxn: 250,600
    scan: 60
    vmaxb: 100g
    vmaxn: 100k
    hist: ${storage}/Services/copyparty-public-drop
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
        "d ${storage}/Services/copyparty-plug 0700 root root -"
        "d ${storage}/Public 0755 copyparty copyparty -"
        "d ${storage}/Drop 0755 copyparty copyparty -"
        "d ${storage}/Services/copyparty-public 0700 copyparty copyparty -"
        "d ${storage}/Services/copyparty-public-hist 0700 copyparty copyparty -"
        "d ${storage}/Services/copyparty-public-plug 0700 copyparty copyparty -"
        "d ${storage}/Services/copyparty-public-drop 0700 copyparty copyparty -"
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
          # Hist dirs (deterministic; the tmpfiles `d` rules heal at boot).
          install -d -m 0700 ${storage}/Services/copyparty
          install -d -m 0700 ${storage}/Services/copyparty-plug
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
          install -d -m 0755 -o copyparty -g copyparty ${storage}/Drop
          install -d -m 0700 -o copyparty -g copyparty ${storage}/Services/copyparty-public
          install -d -m 0700 -o copyparty -g copyparty ${storage}/Services/copyparty-public-hist
          install -d -m 0700 -o copyparty -g copyparty ${storage}/Services/copyparty-public-plug
          install -d -m 0700 -o copyparty -g copyparty ${storage}/Services/copyparty-public-drop
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
          # ?th= conversions take 1-2 minutes before the first response
          # byte (one-time per file/track, cached afterwards). nginx's
          # default 60s proxy_read_timeout killed the upstream connection
          # mid-conversion: the phone got a 504 HTML page ("Can't play
          # media (invalid MIME type)"), while the conversion kept running
          # in the background — which is exactly why an immediate retry
          # "just worked". Stream unbuffered so nginx does not also write
          # a second copy of multi-GB files to disk.
          extraConfig = ''
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_buffering off;
          '';
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

      # Void directory (public write-only drop-box): per the void-directory
      # spec §8, surface an explicit "Drop files" link so the /drop target
      # is discoverable. Config-only — no copyparty source patch, and upload
      # to /drop is intentionally ALLOWED for anonymous visitors (w: *); the
      # volume itself cannot be listed/downloaded (no r). Placed next to
      # "Public Files" so operators can copy the drop URL.
      modules.homer.services.Documents."Drop files" = {
        logo = ./copyparty.svg;
        url = "https://files.${vars.publicDomainName}/drop";
      };
    }
  ]);
}
