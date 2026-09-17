{
  lib,
  pkgs,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.matrix;

  # Server name under the public domain. Conduit uses it as the namespace
  # for all IDs on this server (@user:matrix.skylake.mihaly.codes,
  # #room:matrix.skylake.mihaly.codes). A subdomain server_name keeps the
  # whole Matrix surface on one vhost and avoids touching the apex
  # (skylake.mihaly.codes, which already belongs to homer-public).
  serverName = "matrix.${vars.publicDomainName}";

  # Conduit's listen port. mkService exposes it privately: nginx proxies
  # from the public vhost on loopback, the port is tailnet-only
  # (tailnetRules) and closed to the WAN (default-DROP input policy) — the
  # internet only ever sees 80/443, exactly like the other public services.
  port = 6167;

  # The web client (Element Web) served at the vhost root. Its shipped
  # config.json defaults to matrix.org; `conf` is deep-merged over it
  # (jq `.[0] * $conf`), so we only pin the homeserver and keep the rest
  # of the defaults (identity server, integrations, ...).
  elementWeb = pkgs.element-web.override {
    conf = {
      default_server_config."m.homeserver" = {
        base_url = "https://${serverName}";
        server_name = serverName;
      };
    };
  };
in
{
  options.modules.matrix = {
    enable = mkEnableOption "matrix (public Conduit homeserver)";

    allowRegistration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow anyone to self-register an account on this server
        (Conduit allow_registration). A Matrix server on the public
        internet with fully open registration is a magnet for
        spam/bot accounts; consider setting
        modules.matrix.registrationToken so only people who know the
        shared token can register.
      '';
    };

    registrationToken = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Optional shared token that new users must present when
        registering (Conduit registration_token). With this set,
        registration stays open to anyone who knows the token but is
        closed to bots. Leave null for fully open registration.
      '';
    };

    maxRequestSize = mkOption {
      type = types.ints.positive;
      default = 100 * 1024 * 1024; # 100 MiB
      description = ''
        Maximum request/upload size Conduit will accept, plus the
        matching nginx client_max_body_size (bytes). Keep both equal;
        nginx defaults client_max_body_size to 1 MiB, so without this
        files larger than 1 MiB would fail at the proxy.
      '';
    };

    elementWeb = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Serve the Element Web client at the vhost root. Element X's
          account-creation flow requires the Matrix Authentication
          Service (MAS, /_matrix/client/v1/register), which Conduit
          does not implement — its in-app "create account" therefore
          fails with "your homeserver needs to be upgraded...".
          Element Web uses the legacy /_matrix/client/v3/register flow
          Conduit supports, so it can create the first account (which
          Conduit grants admin). With this on,
          https://matrix.<publicDomain>/ is the login/register page.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkService {
    subdomain = "matrix";
    inherit port;

    # Public: https://matrix.${publicDomainName} — nginx (Let's Encrypt)
    # proxies to 6167 on loopback. The port itself stays tailnet/loopback
    # only via mkService (tailnetRules + the WAN stays closed).
    public = true;

    dashboard = {
      category = "Chat";
      name = "Matrix";
      logo = ./matrix.svg;
    };

    extraConfig = {
      # --- homeserver: Conduit (Rust — orders of magnitude lighter than
      # Synapse, chosen for skylake's 4 GB) --------------------------------
      services.matrix-conduit = {
        enable = true;
        settings = {
          global = {
            server_name = serverName;
            # Bind everywhere; mkService's firewall + the loopback-only
            # nginx proxy keep it reachable from the tailnet/loopback
            # only, never from the WAN directly.
            address = "0.0.0.0";
            inherit port;
            max_request_size = cfg.maxRequestSize;
            # Federation (server-to-server with matrix.org & co.), which
            # is what makes a "public" Matrix server actually public.
            allow_federation = true;
            allow_registration = cfg.allowRegistration;
            # trusted_servers defaults to [ matrix.org ] in the module.
          }
          // optionalAttrs (cfg.registrationToken != null) {
            registration_token = cfg.registrationToken;
          };
        };
      };

      # --- nginx (public vhost) -------------------------------------------
      services.nginx.virtualHosts."${serverName}" = {
        extraConfig = ''
          # Without this nginx cuts uploads at 1 MiB before Conduit ever
          # sees them (keep in sync with max_request_size above).
          client_max_body_size ${toString cfg.maxRequestSize};
        '';

        locations = {
          # Server discovery / delegation: other homeservers resolve
          # ${serverName} via this well-known file and then federate over
          # the existing 443 vhost — so federation needs NO extra public
          # port (the WAN stays 80/443 only).
          "/.well-known/matrix/server" = {
            extraConfig = ''
              default_type application/json;
              # Explicit :443 (rather than the legacy :8448 default).
              return 200 '{"m.server":"${serverName}:443"}';
            '';
          };
          # Client discovery: lets Matrix clients find the homeserver from
          # the URL they are given (also enables simplified sliding sync).
          "/.well-known/matrix/client" = {
            extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin * always;
              add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
              add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
              return 200 '{"m.homeserver":{"base_url":"https://${serverName}"}}';
            '';
          };
          # Matrix API (client-server + federation + media + sliding
          # sync): reverse-proxy to Conduit. Keep the upgrade headers +
          # unbuffered request so WebSocket endpoints and large uploads
          # work through the proxy.
          "/_matrix" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_request_buffering off;
            '';
          };
          # Element Web at the vhost root (see the elementWeb option).
          # Serve the web client statically; mkService's publicConfig had
          # wired "/" to proxy to the service port, so that proxyPass is
          # neutralized with mkForce. Every other path (well-known,
          # /_matrix) has a longer prefix and wins over "/".
          "/" = mkIf cfg.elementWeb.enable {
            proxyPass = lib.mkForce null;
            recommendedProxySettings = false;
            root = elementWeb;
            index = "index.html";
            # Element Web is a SPA: fall back to index.html for any path
            # that is not a real file (1.12+ uses browser-history routing).
            tryFiles = "$uri $uri/ /index.html";
          };
        };
      };
    };
  });
}
