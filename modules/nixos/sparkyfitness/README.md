# SparkyFitness (private, tailnet-only)

Self-hosted family nutrition/fitness tracker (upstream:
<https://github.com/CodeWithCJ/SparkyFitness>). Runs Nix-native (no Docker):
the upstream flake's `sparkyfitness-server` / `sparkyfitness-frontend` packages
plus a local `services.postgresql` (PostgreSQL 16).

## Access

Not public. The web app is served by nginx on a tailnet-only port:

- Web UI / API: `http://${vars.domainName}:3020` (e.g.
  `http://skylake.anaconda-snapper.ts.net:3020`)
- The tailnet vhost redirects `/fitness` → that URL, and the homer dashboard
  card points at it.
- The backend API alone listens on `127.0.0.1:3010` (loopback-only, not
  firewalled open) and is only reachable through nginx's proxy.

The firewall keeps port 3020 reachable from `tailscale0` (or loopback) only —
the WAN never sees the app (default-DROP input policy, same as every other
private service on skylake).

## Secrets

`secrets/server/sparkyfitness.age` (agenix env-file) — `SPARKY_FITNESS_DB_PASSWORD`,
`SPARKY_FITNESS_APP_DB_PASSWORD`, `SPARKY_FITNESS_API_ENCRYPTION_KEY`,
`BETTER_AUTH_SECRET`. Re-encrypt with:

```
nix run nixpkgs#age -- -e \
  -r "ssh-ed25519 AAAA... mihaly@mihaly.codes" \
  -r "ssh-ed25519 AAAA... skylake" \
  -o secrets/server/sparkyfitness.age /tmp/plain.env
```

## Upgrade

The upstream flake input (`sparkyfitness` in `flake.nix`) is updated with
`make update` like the rest. The backend runs DB migrations on startup.

## Garmin microservice

Disabled. Enable with `services.sparkyfitness.garmin.enable = true` if you
want Garmin Connect sync (its own `sparkyfitness-garmin` systemd service and
user).