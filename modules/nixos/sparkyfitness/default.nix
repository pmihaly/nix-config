{
  lib,
  pkgs,
  config,
  inputs,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.sparkyfitness;

  # Tailnet-only app endpoint: nginx serves the static frontend + proxies the
  # API on a dedicated port (same pattern as deluge/immich/it-tools raw ports).
  # Must match services.sparkyfitness.frontendUrl: the backend derives CORS
  # and Better Auth trusted origins from it, and reuses it for callbacks.
  appPort = 3020;
  frontendUrl = "http://${vars.domainName}:${toString appPort}";

  # Backend API listen port (loopback-only; only nginx reaches it).
  backendPort = 3010;

  # Upstream flake packages: Nix-native builds of the backend (tsx, no
  # compile step) and the static Vite frontend bundle — no Docker on
  # skylake. The garmin microservice is not pulled in (see README.md).
  upstream = inputs.sparkyfitness;
  serverPackage = upstream.packages.${pkgs.system}.sparkyfitness-server;
  frontendPackage = upstream.packages.${pkgs.system}.sparkyfitness-frontend;
in
{
  # The upstream module is imported as-is (services.sparkyfitness); this
  # module only wires it into the repo's mkService conventions (nginx front,
  # dashboard card, tailnet-only port) and supplies the secrets. The bare
  # module (nixosModules.default) leaves backendPackage/frontendPackage
  # unset — the convenience nixosModules.sparkyfitness would also define
  # them, colliding with our explicit packages below.
  imports = [ upstream.nixosModules.default ];

  options.modules.sparkyfitness = {
    enable = mkEnableOption "sparkyfitness (self-hosted family fitness tracker)";

    disableSignup = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Block new account signups at the login page
        (SPARKY_FITNESS_DISABLE_SIGNUP). The app is tailnet-only, but the
        whole household's health data lives in it — consider setting this
        to true once the family accounts exist (existing accounts keep
        working; only new signups are blocked).
      '';
    };
  };

  config = mkIf cfg.enable (mkService {
    subdomain = "fitness";
    # User-facing tailnet port (frontend + API, see below). mkService opens
    # it for the tailnet only, registers the /fitness redirect on the tailnet
    # vhost and the homer card. The backend's own port (3010) stays
    # loopback-only — no firewall rule, so it is reachable by nginx only.
    port = appPort;

    # NOT public: never exposed to the internet (no domain name, no ACME).
    # See README.md — family health data stays on the tailnet.
    public = false;

    dashboard = {
      category = "Health";
      name = "SparkyFitness";
      # Shipped as part of the frontend's public/ dir (Vite copies it to the
      # dist root); homer mounts the store path into its container.
      logo = "${frontendPackage}/images/icons/icon-512x512.png";
    };

    extraConfig = {
      # --- SparkyFitness services (upstream module) --------------------------
      services.sparkyfitness = {
        enable = true;
        inherit frontendPackage;
        backendPackage = serverPackage;
        inherit frontendUrl;
        # Secrets (DB passwords, encryption key, auth secret) — agenix
        # env-file, decrypted to /run/agenix at activation, never in the
        # Nix store. See secrets/secrets.nix.
        environmentFile = config.age.secrets."server/sparkyfitness".path;
        # The upstream module wires its own nginx vhost; this repo runs all
        # traffic through its central nginx (tailnet vhost + per-service raw
        # ports via mkService). The same proxy routes are declared by hand
        # below on the tailnet-only app vhost.
        nginx.enable = false;
        # Garmin Connect microservice: disabled (its own python/uvicorn
        # service; skylake's 4 GB). Enable via
        # services.sparkyfitness.garmin.enable at any time.
        extraEnvironment = optionalAttrs cfg.disableSignup {
          SPARKY_FITNESS_DISABLE_SIGNUP = "true";
        };
      };

      # --- Secrets: env-file with DB passwords, API encryption key and
      # Better Auth secret. Owner is root because systemd (not the service
      # user) reads the EnvironmentFile; both sparkyfitness-db-init
      # (postgres user) and sparkyfitness (backend) reference the path.
      age.secrets."server/sparkyfitness" = {
        file = ../../../secrets/server/sparkyfitness.age;
        owner = "root";
        group = "root";
        mode = "400";
      };

      # --- nginx: tailnet-only app vhost -------------------------------------
      # Serves the static SPA and reverse-proxies the API + uploads on a
      # dedicated port. The vhost is bound to the firewall-restricted tailnet
      # port (mkService's tailnetRules) — it is the ONLY listener on 3020, so
      # nginx treats it as the default server for that socket no matter what
      # Host header the client sends (IP, ts.net name, or localhost).
      services.nginx.virtualHosts."sparkyfitness" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = appPort;
          }
        ];
        root = frontendPackage;
        locations = {
          # Static SPA with client-side routing.
          "/" = {
            tryFiles = "$uri $uri/ /index.html";
            extraConfig = ''
              expires -1;
              add_header Cache-Control "no-cache, no-store, must-revalidate";
            '';
          };

          "/assets/" = {
            extraConfig = ''
              expires 1y;
              add_header Cache-Control "public, no-transform, immutable";
              try_files $uri =404;
            '';
          };

          # API reverse proxy.
          "^~ /api/" = {
            proxyPass = "http://127.0.0.1:${toString backendPort}";
          };

          # Mobile/health-data clients hit /health-data; the backend serves
          # it under /api.
          "/health-data" = {
            proxyPass = "http://127.0.0.1:${toString backendPort}/api/health-data";
          };

          # Uploaded files are served by the backend.
          "^~ /uploads/" = {
            proxyPass = "http://127.0.0.1:${toString backendPort}/uploads/";
          };

          # External MCP endpoint (JSON-RPC over StreamableHTTP). Buffering
          # off + Connection cleared so text/event-stream responses stream.
          "^~ /mcp" = {
            proxyPass = "http://127.0.0.1:${toString backendPort}";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              proxy_buffering off;
            '';
          };
        };

        extraConfig = ''
          client_max_body_size 10m;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
        '';
      };
    };
  });
}
