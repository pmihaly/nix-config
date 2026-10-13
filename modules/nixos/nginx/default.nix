{
  lib,
  config,
  vars,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.nginx;
  # The MagicDNS tailnet name (vars.domainName, e.g.
  # skylake.anaconda-snapper.ts.net) carries the private dashboard boards
  # and per-service proxy/redirect locations. It must terminate TLS with a
  # real certificate — without a :443 listener the name falls through to
  # whatever vhost is the 443 default_server, which presents a cert for a
  # different name and browsers show a blank/error page.
  # MagicDNS names cannot use Let's Encrypt (no DNS control for ts.net), so
  # the cert comes from `tailscale cert` — Tailscale provisions a real
  # LE-backed cert for *.ts.net via the tailnet's HTTPS capability. A root
  # systemd oneshot fetches/renews it (see below); the files live under the
  # already-persisted /var/lib/tailscale so they survive impermanence.
  tsCertDir = "/var/lib/tailscale/certs";
  tsCert = "${tsCertDir}/${vars.domainName}.crt";
  tsKey = "${tsCertDir}/${vars.domainName}.key";

  # nginx (the unit runs as User=nginx since the 2026-09-23 nixpkgs bump)
  # reads TLS certs as the nginx user, but /var/lib/tailscale is 0700 root
  # by design — tailscaled re-chmods its state dir on EVERY start, including
  # the restarts during each deploy activation, which happens AFTER the
  # activation scripts run. So nginx can never reliably traverse it (the
  # tmpfiles/activationScript chmod o+x hack below was exactly that race,
  # first hit on the 2026-10-13 deploy). Instead the cert oneshot (root)
  # copies the certificates into an nginx-readable dir and the vhost uses
  # the copies; nginx never touches /var/lib/tailscale.
  tsCopyDir = "/var/lib/nginx/tailscale-certs";
  tsCertCopy = "${tsCopyDir}/${vars.domainName}.crt";
  tsKeyCopy = "${tsCopyDir}/${vars.domainName}.key";
  ts = config.services.tailscale;
in
{
  options.modules.nginx = {
    enable = mkEnableOption "nginx";
  };
  config = mkIf cfg.enable {

    services.nginx = {
      enable = true;

      virtualHosts."${vars.domainName}" = {
        globalRedirect = "${vars.domainName}/homer";

        # Serve the ts.net vhost on :443 too (keeps the existing :80
        # redirects); TLS terminates with the Tailscale-issued cert.
        addSSL = mkIf ts.enable true;
        sslCertificate = mkIf ts.enable tsCertCopy;
        sslCertificateKey = mkIf ts.enable tsKeyCopy;
      };

      experimentalZstdSettings = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;
    };

    # Fetch/renew the Tailscale cert for the MagicDNS name as root
    # (tailscale cert requires the daemon operator, i.e. root), before nginx
    # starts so nginx never attempts -t/config-load with a missing cert.
    # Runs once at boot and on a weekly timer; `--min-validity` makes the
    # fetch a no-op until the cert is actually near expiry. nginx is reloaded
    # only when the cert file changed.
    systemd.services."tailscale-cert-${vars.domainName}" = mkIf ts.enable {
      description = "Fetch TLS certificate for ${vars.domainName} from Tailscale";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      before = [ "nginx.service" ];
      path = [ pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -e
        mkdir -p ${tsCertDir}
        # Tailscale cert fetches from the control plane, which needs
        # tailscaled to be connected first — a plain `After=tailscaled`
        # isn't enough (the daemon unit is active before the first netmap
        # sync). Retry until the cert is present or we give up.
        TSBIN=${config.services.tailscale.package}/bin/tailscale
        LOG=/var/log/tailscale-cert.log
        : > "$LOG"
        before=$(cksum ${tsCert} 2>/dev/null || true)
        for attempt in $(seq 1 20); do
          if "$TSBIN" cert \
            --min-validity=720h \
            --cert-file=${tsCert} \
            --key-file=${tsKey} \
            ${vars.domainName} >>"$LOG" 2>&1; then
            break
          fi
          echo "attempt $attempt failed, retrying in 5s" >>"$LOG"
          sleep 5
        done

        # If the cert still isn't there after all attempts, fail loudly so
        # the operator sees why (ACL denied, tailnet not upgraded, ...).
        if [ ! -s ${tsCert} ]; then
          echo "FATAL: no cert after 20 attempts; last error above" >>"$LOG"
          cat "$LOG" >&2
          exit 1
        fi

        # Refresh the nginx-readable copies (tsCopyDir above) so nginx -t/
        # reloads never depend on traversing the 0700 root /var/lib/tailscale.
        # Runs before nginx starts (Before=nginx.service) and on every renewal,
        # so the copies are always the current cert.
        install -d -o root -g nginx -m 0750 ${tsCopyDir}
        install -o root -g nginx -m 0640 ${tsCert} ${tsCertCopy}
        install -o root -g nginx -m 0640 ${tsKey} ${tsKeyCopy}

        chmod 644 "$LOG"
        after=$(cksum ${tsCert} 2>/dev/null || true)
        if [ "$before" != "$after" ]; then
          # Renewal path (timer): nginx is already running and must pick up
          # the new cert. Clear the failure limiter first (activation may
          # have tripped start-limit-hit while the cert was missing), then
          # try-restart. MUST be gated on nginx being active: during boot /
          # deploy-activation nginx is still inactive and waiting on this
          # oneshot via After=/wants= — an unconditional try-restart here
          # deadlocks (nginx waits on this service, this service waits on
          # the nginx job).
          if systemctl is-active --quiet nginx.service; then
            systemctl reset-failed nginx.service || true
            systemctl try-restart nginx.service || true
          fi
        fi
      '';
    };

    # On boot AND on deploy-activation restarts of nginx, wait for the cert
    # oneshot to have produced the certificate before nginx's `nginx -t`
    # pre-start runs — otherwise nginx refuses to start (missing ssl cert).
    systemd.services.nginx = mkIf ts.enable {
      after = [ "tailscale-cert-${vars.domainName}.service" ];
      wants = [ "tailscale-cert-${vars.domainName}.service" ];
    };

    systemd.timers."tailscale-cert-${vars.domainName}" = mkIf ts.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    # Superseded by the tsCopyDir copy approach above: nginx reads the
    # certs from $tsCopyDir, so /var/lib/tailscale ownership can stay 0700
    # root and tailscaled's re-chmod on restart is harmless.


    networking.firewall = {
      enable = true;
      # Web ports only. SSH is deliberately NOT opened here: on skylake it is
      # tailnet-only (machines/skylake/default.nix); on desktops
      # services.openssh.openFirewall (shell use-case) still exposes it.
      allowedTCPPorts = [
        80
        443
      ];
    };
  };
}
