{
  inputs,
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.hermes-agent;

  # Hermes' built-in dashboard port (web_server.py default; the NixOS
  # module's backend.port also defaults to it).
  port = 9119;
in
{
  options.modules.hermes-agent = {
    enable = mkEnableOption "Hermes Agent (Nous Research) — agent gateway + web dashboard";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.hermes-agent = {
        enable = true;

        # The `minimal` variant: core app only, without the optional
        # integration groups (matrix, voice, modal, daytona, …) that the
        # default `full` build pulls in. Skylake talks to LLMs over an
        # OpenAI-compatible endpoint (part of the core), so nothing needed
        # is missing. Rebuild-time difference is substantial. Add groups
        # back via `package = ... .override { extraDependencyGroups = [...]; }`
        # if a specific integration (e.g. `messaging`) is ever wanted.
        package = inputs.hermes-agent.packages.${pkgs.stdenv.system}.minimal;

        # LLM backend: llama-swap on aesop over the tailnet (OpenAI
        # compatible, model `Qwen3.8-27B Q4 +MTP` served by llama-cpp-rocm).
        # Nothing here is secret: the tailnet hostname is in this repo and
        # llama-swap doesn't enforce auth (api_key is a formality). The
        # ts.net name survives aesop tailnet-IP changes.
        #
        # NOTE on merge direction: the activation script deep-merges these
        # settings INTO the runtime config.yaml with Nix keys winning
        # (nix/configMergeScript.nix). So if you switch models in the
        # dashboard, the next `make skylake` re-asserts the value below.
        # Update `settings` here to change the default model.
        settings = {
          providers.local = {
            api = "http://aesop.anaconda-snapper.ts.net:8081/v1";
            api_key = "local";
          };
          model = {
            default = "Qwen3.8-27B Q4 +MTP";
            provider = "custom:local";
          };
        };

        # State on /persist: skylake's root is tmpfs (impermanence), so the
        # module's default /var/lib/hermes would vanish on every reboot.
        # vars.serviceConfig is already in the restic backup list
        # (modules-v2/nixos/backup via machines/skylake).
        stateDir = "${vars.serviceConfig}/hermes";
        # workingDirectory stays the module default: ${stateDir}/workspace.

        backend = {
          # The browser dashboard (the web UI) on 9119.
          mode = "dashboard";

          # Loopback bind => the dashboard's auth gate stays OFF (no login
          # page, single-user by construction). should_require_dashboard_auth()
          # in web_server.py only engages the gate for non-loopback binds or
          # a configured dashboard.public_url; --insecure can no longer
          # disable it, so loopback is the only gate-free mode.
          #
          # Tailnet access comes through nginx instead: the /hermes
          # location on the ts.net vhost (below) proxies to this port with
          #   - Host rewritten to 127.0.0.1  (the dashboard's Host-header
          #     guard only accepts loopback names for loopback binds),
          #   - Origin dropped               (the WS Origin guard treats a
          #     missing Origin as allowed),
          #   - X-Forwarded-Prefix: /hermes  (the prefix-aware SPA rewrites
          #     its own asset URLs; see mount_spa() in web_server.py).
          # The app sees nginx as a 127.0.0.1 peer, so the WS loopback-peer
          # check passes too (uvicorn proxy_headers stays off without the
          # gate, so X-Forwarded-For can't defeat it).
          host = "127.0.0.1";
          inherit port;
        };
      };
    }

    {
      # Internal-only exposure: the ts.net vhost is served on public 80,
      # so the location is restricted to tailnet source addresses
      # (100.64.0.0/10) at the nginx layer.
      # Two locations, and the trailing slash in the second one is LOAD
      # BEARING: when proxy_pass has a URI part, nginx strips exactly the
      # location NAME from the request URI (src/http/modules/
      # ngx_http_proxy_module.c: loc_len = min(location.len, uri.len)) and
      # then prepends the proxy_pass URI. So:
      #   location /hermes  + proxy_pass http://…9119/;  ->  //assets/…
      #   location /hermes/ + proxy_pass http://…9119/;  ->  /assets/…
      # The double slash is not matched by the app's /assets static mount
      # and falls into the SPA catch-all, which serves index.html for
      # every request (blank white page). Verified against nginx 1.30.4
      # source and by strace.
      services.nginx.virtualHosts."${vars.domainName}".locations = {
        # Without this exact match, a bare /hermes would fall into the
        # vhost's `location /` (301 to /homer…).
        "= /hermes" = {
          extraConfig = ''
            allow 100.64.0.0/10;
            deny all;
            return 301 /hermes/;
          '';
        };

        "/hermes/" = {
          # proxy_pass WITH a URI ("/") strips the /hermes/ prefix:
          # /hermes/api/x -> /api/x, which is what the app routes on.
          # (The X-Forwarded-Prefix header is only used to rewrite the
          # served SPA's asset URLs, not for routing.)
          proxyPass = "http://127.0.0.1:${toString port}/";
          proxyWebsockets = true;

          # The recommended proxy settings are `include`d AFTER extraConfig
          # in the generated config and would reset Host to $host,
          # overriding the rewrite the loopback Host-guard requires — so
          # disable them and set the headers manually.
          recommendedProxySettings = false;

          extraConfig = ''
            # Tailnet-only (see above).
            allow 100.64.0.0/10;
            deny all;

            # Must match a loopback name for the dashboard's Host-header
            # guard (DNS-rebinding protection).
            proxy_set_header Host 127.0.0.1;
            # Empty value => nginx omits the header; the WS Origin guard
            # accepts a missing Origin.
            proxy_set_header Origin "";
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            # Tells the SPA to serve assets under /hermes (mount_spa()).
            proxy_set_header X-Forwarded-Prefix /hermes;

            # Agent runs / LLM calls can be long; don't cut them off.
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };

      # Card on the private Homer board.
      modules.homer.services.AI.Hermes = {
        logo = ./hermes.png;
        url = "http://${vars.domainName}/hermes/";
      };
    }
  ]);
}
