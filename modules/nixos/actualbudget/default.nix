{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.actualbudget;

  # Tailnet-private Actual Budget (https://actualbudget.org): the nixpkgs
  # `actual-server` package bundles the Node sync-server AND the desktop
  # web UI (packages/desktop-client/build, auto-served via ACTUAL_WEB_ROOT's
  # default) in one process.
  #
  # Plain HTTP on the tailnet port, like every other internal service, with
  # the login page effectively disabled: at every boot the bootstrap oneshot
  # writes /actual-auto-login.js next to the app's data (containing the
  # admin password), and nginx injects that same-origin script into
  # index.html. The script (1) enables Actual's official no-
  # SharedArrayBuffer override (plain HTTP is not a secure context, so SAB
  # is unavailable — the app's "Advanced options" escape hatch, auto-,
  # enabled, self-cleared by the app whenever SAB exists) and (2) when the
  # app renders the login page (fresh browser / incognito), autofills and
  # submits the form with the admin password via the app's own bindings —
  # so the login page flashes by without any typing. Browsers with a stored
  # session never render the form and the script no-ops. (The client's
  # session token cannot be pre-seeded from a page script: the app keeps it
  # in a worker-private IndexedDB.) Only the tailnet vhost injects this;
  # the public HTTPS vhost stays password-gated.
  #
  #   browser ── http://skylake…ts.net:5006 ──► nginx (tailnet-only)
  #                                                  │
  #                                                  ▼
  #                                    actual-server @ 127.0.0.1:5007
  tailnetPort = 5006;
  appPort = 5007;

  # Persisted data dir: the server keeps its account DB (users/sessions,
  # created by the first-run bootstrap) under server-files/ and the budget
  # data per user under user-files/. actual-auto-login.js (written by the
  # bootstrap oneshot) lives here too, served by nginx.
  dataDir = "/var/lib/actualbudget";
in
{
  options.modules.actualbudget = {
    enable = mkEnableOption "actualbudget (self-hosted budgeting, tailnet-private)";
  };

  config = mkIf cfg.enable (mkService {
    subdomain = "budget";
    port = tailnetPort;

    # Private: finances stay on the tailnet — no public domain, no ACME,
    # no TLS. mkService opens ${tailnetPort} tailnet-only and registers the
    # http homer card (default) as usual.
    public = false;

    dashboard = {
      category = "Finance";
      name = "Actual Budget";
      # App icon shipped in the nixpkgs build; homer mounts the store path
      # into its container.
      logo = "${pkgs.actual-server}/lib/actual/packages/desktop-client/build/android-chrome-192x192.png";
    };

    extraConfig = {
      # --- HTTP front on the tailnet port --------------------------------
      # Proxy the app (bound to loopback only) behind nginx on the tailnet
      # port so the auto-login script can be injected into index.html.
      services.nginx.virtualHosts."actualbudget" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = tailnetPort;
          }
        ];
        # Only listener on this socket, so it answers whatever Host header
        # the browser sends.
        default = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString appPort}";
          extraConfig = ''
            # sub_filter needs the upstream response uncompressed.
            proxy_set_header Accept-Encoding "";
            # Inject the auto-login script into the app's index.html
            # (text/html only, first match, CSP-compatible: same-origin
            # script, script-src 'self').
            sub_filter_once on;
            sub_filter '</head>' '<script src="/actual-auto-login.js"></script></head>';
          '';
        };
        locations."/actual-auto-login.js" = {
          # root (not alias): the full request path is appended to the
          # dir, and the file lives under that exact name.
          root = dataDir;
        };
      };

      # --- Public HTTPS vhost for Enable Banking bank sync ----------------
      # EB's OAuth redirect URL is derived from the app's own origin
      # (window.location.origin + '/enablebanking/auth_callback'), must be
      # HTTPS + a public domain (https://actualbudget.org/docs/advanced/
      # bank-sync/enable-banking), and the client refuses to start the flow
      # over http — so the app is ALSO reachable at
      # https://budget.${vars.publicDomainName}. This origin is login-gated:
      # the auto-login injection above lives ONLY on the tailnet vhost, so
      # the admin password protects the public URL (rate-limited 5/15 min,
      # 96-bit random password). All data paths (/sync, /download-user-file,
      # /admin/..., /secret/...) require the session token; the only
      # unauthenticated surface here is the static UI, /info-/health-style
      # info, the rate-limited /account/login, and the EB OAuth callback
      # (an error-only handler without a fresh OAuth code).
      services.nginx.virtualHosts."budget.${vars.publicDomainName}" = {
        forceSSL = true;
        enableACME = true;
        # Same webroot the other public vhosts use for HTTP-01.
        acmeRoot = "/var/lib/acme/acme-challenge";
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString appPort}";
        };
        # Block web crawlers / AI agents from indexing the public UI
        # (same pattern as the other public vhosts).
        locations."=/robots.txt" = {
          return = ''200 "User-agent: *\nDisallow: /\n"'';
        };
        locations."=/agents.txt" = {
          return = "200 out:all\n";
        };
      };

      # ACME account + webroot for the public vhost (idempotent — the other
      # public services already set these on skylake).
      security.acme = {
        acceptTerms = true;
        defaults.email = vars.acmeEmail;
      };
      systemd.tmpfiles.rules = [
        "d /var/lib/acme/acme-challenge 0750 acme nginx -"
        "z /var/lib/acme/acme-challenge 0750 acme nginx -"
      ];

      # --- Secrets: the admin password for the first-run bootstrap.
      # env-file (ACTUAL_ADMIN_PASSWORD), decrypted to /run/agenix at
      # activation, never in the Nix store. Owner is root because systemd
      # (not the service user) reads the EnvironmentFile. The secret file
      # itself is registered for rekey in secrets/secrets.nix.
      age.secrets."server/actualbudget" = {
        file = ../../../secrets/server/actualbudget.age;
        owner = "root";
        group = "root";
        mode = "400";
      };

      users.groups.actualbudget = { };
      users.users."actualbudget" = {
        isSystemUser = true;
        group = "actualbudget";
        home = dataDir;
        description = "Actual Budget server";
      };

      # Data survives impermanence: StateDirectory creates /var/lib/
      # actualbudget on first start; the persistence entry keeps it across
      # reboots (same pattern as /var/lib/private/matrix-conduit).
      environment.persistence.${vars.persistDir}.directories = [ dataDir ];

      systemd.services.actualbudget = {
        description = "Actual Budget server (tailnet-private finance manager)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          User = "actualbudget";
          Group = "actualbudget";
          StateDirectory = "actualbudget";
          ExecStart = "${pkgs.actual-server}/bin/actual-server";
          # Loopback-only bind: only nginx (the front) reaches the app.
          # ACTUAL_TOKEN_EXPIRATION=never keeps the single shared session
          # token valid forever, which the auto-login script relies on.
          Environment = [
            "ACTUAL_DATA_DIR=${dataDir}"
            "ACTUAL_HOSTNAME=127.0.0.1"
            "ACTUAL_PORT=${toString appPort}"
            "ACTUAL_TOKEN_EXPIRATION=never"
          ];
          Restart = "on-failure";
          # The server only ever writes under ${dataDir}; sandbox it.
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ dataDir ];
          PrivateTmp = true;
        };
      };

      # First-run bootstrap + login-page suppression. Idempotent, runs at
      # every boot: waits for the server, bootstraps the password auth +
      # owner ADMIN account if needed (so the "start using a server" page
      # never shows), then logs in and writes the auto-login script for
      # nginx to inject — the browser gets a valid session token without
      # ever seeing a login form.
      systemd.services.actualbudget-bootstrap = {
        description = "Actual Budget bootstrap + auto-login seeding";
        wantedBy = [ "multi-user.target" ];
        after = [ "actualbudget.service" ];
        requires = [ "actualbudget.service" ];
        path = [
          pkgs.curl
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          # Admin password (env-file, ACTUAL_ADMIN_PASSWORD); read by
          # systemd as root, never written to the Nix store.
          EnvironmentFile = config.age.secrets."server/actualbudget".path;
        };
        script = ''
          set -euo pipefail

          # The account API lives under /account/ (the SPA fallback would
          # otherwise answer 200 with index.html).
          url="http://127.0.0.1:${toString appPort}/account"

          # Wait for the server to accept requests (first start creates
          # the DB files before the HTTP listener is up).
          up=0
          for _ in $(seq 1 60); do
            if curl -fsS -o /dev/null "$url/needs-bootstrap"; then
              up=1
              break
            fi
            sleep 1
          done
          if [ "$up" != 1 ]; then
            echo "actualbudget: server did not answer in time, skipping bootstrap" >&2
            exit 1
          fi

          # First run: create the password auth method + the owner ADMIN
          # account (idempotent — errors are fine if it already exists).
          # The password is alphanumeric (generated with `openssl rand
          # -hex`), so no JSON escaping is needed.
          curl -sS -X POST "$url/bootstrap" \
            -H 'Content-Type: application/json' \
            --data "$(printf '{"password":"%s"}' "$ACTUAL_ADMIN_PASSWORD")" \
            >/dev/null || true

          # The seeded TOKEN is no longer written directly into the client
          # storage (the app's IndexedDB is worker-internal and not
          # reachable from page scripts) — instead the script LOGS IN with
          # the admin password by autofilling + submitting the app's own
          # login form, exactly what a human would do, invisible.
          cat > ${dataDir}/actual-auto-login.js <<EOF
          // Written by the actualbudget-bootstrap oneshot (root), served
          // only on the tailnet origin (the public HTTPS vhost never
          // injects this). Keeps the app "logged in as admin" over plain
          // HTTP:
          //  1. Enables Actual's official no-SharedArrayBuffer override
          //     (HTTP is not a secure context, so SAB is unavailable; this
          //     is exactly what the app's "Advanced options" button sets;
          //     the app clears the flag itself whenever SAB exists).
          //  2. Auto-signs in: when the app shows the login page (fresh
          //     browser / incognito), fills the password field and submits
          //     the form using the app's own bindings, so the login page
          //     flash-es by without any typing. Browsers with a stored
          //     session never render the form, so this no-ops there.
          try { localStorage.setItem('SharedArrayBufferOverride', 'true'); } catch (e) {}
          (function () {
            // The login page is NOT a <form>: it is a password input whose
            // onEnter submits + a "Sign in" button. So: set the native
            // value, let the app's onChange handler pick it up, then send
            // Enter, then click the button as backup after the state has
            // re-rendered.
            var PASSWORD = '$ACTUAL_ADMIN_PASSWORD';
            var attempts = 0;
            function findButton(input) {
              var c = input.parentElement;
              if (c) {
                var b = c.querySelector('button');
                if (b) return b;
              }
              var found = null;
              Array.prototype.forEach.call(document.querySelectorAll('button'),
                function (b) {
                  if (!found && b.textContent && b.textContent.trim() === 'Sign in') found = b;
                });
              return found;
            }
            function tryLogin() {
              attempts++;
              var input = document.querySelector('input[type="password"]');
              if (!input) {
                if (attempts < 360) setTimeout(tryLogin, 1000);
                return;
              }
              try {
                var set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                set.call(input, PASSWORD);
                input.dispatchEvent(new Event('input', { bubbles: true }));
                input.dispatchEvent(new Event('change', { bubbles: true }));
                // Let React pick up the value, then submit via Enter.
                setTimeout(function () {
                  try {
                    input.dispatchEvent(new KeyboardEvent('keydown', {
                      key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true
                    }));
                  } catch (e2) {}
                  // Backup: click the Sign in button if the page has not
                  // already navigated away.
                  setTimeout(function () {
                    try {
                      if (!document.querySelector('input[type="password"]')) return;
                      var btn = findButton(input);
                      if (btn) btn.click();
                    } catch (e3) {}
                  }, 500);
                }, 250);
              } catch (e4) {}
            }
            setTimeout(tryLogin, 1500);
          })();
          EOF
          chmod 0644 ${dataDir}/actual-auto-login.js
        '';
      };
    };
  });
}
