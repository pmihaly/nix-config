{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.ntfy;

  # ntfy's own default listen address is :80 (it is meant to run fronting
  # everything), so it is set explicitly here.
  listenAddr = "0.0.0.0:2045";
  port = 2045;
in
{
  options.modules.ntfy = {
    enable = mkEnableOption "ntfy (public push notification server)";
  };

  config = mkIf cfg.enable (mkService {
    subdomain = "ntfy";
    inherit port;

    # Public: https://ntfy.${publicDomainName} — nginx (Let's Encrypt)
    # proxies to 2045 on loopback. 2045 is otherwise tailnet-only
    # (mkService's tailnetRules) and closed to the WAN (default-DROP
    # input policy). The wildcard A record covers the subdomain.
    public = true;

    extraConfig = {
      users.groups.ntfy = { };
      users.users.ntfy = {
        isSystemUser = true;
        group = "ntfy";
        home = "/nonexistent";
        description = "ntfy push server";
      };

      systemd.services.ntfy = {
        description = "ntfy push notification server (public)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          User = "ntfy";
          Group = "ntfy";
          NoNewPrivileges = true;
          PrivateTmp = true;
          # Nothing is written to disk (no cache/db/auth files), so the
          # strictest system sandbox is safe.
          ProtectSystem = "strict";
          ProtectHome = true;
          # `serve` subcommand is required: the listen flags only exist
          # there, bare `ntfy` rejects them.
          ExecStart = "${pkgs.ntfy-sh}/bin/ntfy serve --listen-http ${listenAddr}";
          Restart = "on-failure";
        };
      };

      # Streaming + WebSocket handling for the whole location (it is the
      # only path group):
      # - SSE (GET /{topic}/sse): without proxy_buffering off, nginx holds
      #   the stream until the buffer fills and push clients get nothing in
      #   a timely manner. HTTP/1.1 keeps the upstream connection alive
      #   cleanly.
      # - WebSocket (GET /{topic}/ws): nginx sends `Connection: close` to
      #   the upstream by default, which breaks the upgrade handshake and
      #   ntfy answers 400 Bad Request. The Upgrade/Connection headers
      #   must be forwarded explicitly.
      # - Idle streams: nginx's default 60s proxy_read_timeout would kill
      #   an SSE/WS subscription that is waiting for the next message.
      services.nginx.virtualHosts."ntfy.${vars.publicDomainName}".locations."/".extraConfig = ''
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
      '';
    };
  });
}
