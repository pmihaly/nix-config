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
        sslCertificate = mkIf ts.enable tsCert;
        sslCertificateKey = mkIf ts.enable tsKey;
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
            --min-validity=30d \
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

        chmod 644 "$LOG"
        after=$(cksum ${tsCert} 2>/dev/null || true)
        if [ "$before" != "$after" ]; then
          # Clear the failure rate limiter (activation may have hit
          # start-limit-hit while the cert was missing); nginx may not be
          # running yet on a fresh boot, try-restart only reloads when it
          # is active.
          systemctl reset-failed nginx.service || true
          systemctl try-restart nginx.service || true
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
