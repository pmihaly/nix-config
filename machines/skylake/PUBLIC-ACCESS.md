# Skylake public surface

Skylake (Hetzner) is reachable from the internet only through nginx on
ports 80/443. Everything else stays tailnet-only.

## What is public

| Hostname                            | Service                       | Notes                                                                                                                                                                                                                 |
| ----------------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `skylake.mihaly.codes`              | **public Homer** dashboard    | apex, served by the `homer-public` default_server vhost                                                                                                                                                               |
| `homer-public.skylake.mihaly.codes` | **public Homer** dashboard    | same instance, subdomain name                                                                                                                                                                                         |
| `it-tools.skylake.mihaly.codes`     | it-tools (IT tool collection) |                                                                                                                                                                                                                       |
| `files.skylake.mihaly.codes`        | public copyparty              | anonymous `rwmd` share (`/void` volume = write-only, unlistable drop-box); in-browser video player with audio/subtitle track selection (patched copyparty + `video-tracks.js` plugin, see `modules/nixos/copyparty/`) |
| `ntfy.skylake.mihaly.codes`         | ntfy push notifications       | self-hosted [ntfy](https://docs.ntfy.sh), in-memory (no storage), default read-write topics (ntfy.sh model) — see `modules/nixos/ntfy/`                                                                               |
| `matrix.skylake.mihaly.codes`        | **Matrix** homeserver + web client | [Conduit](https://conduit.rs) (Rust, chosen over Synapse for skylake's 4 GB) + **Element Web** at the root URL (login/register page). Element X's in-app account creation needs the Matrix Authentication Service, which Conduit lacks — create the first account on the web page (it becomes admin), then sign in with Element X. Federation via well-known delegation on this vhost — no extra public port. DB+media in `/var/lib/private/matrix-conduit` (persisted). Admin = invite to the `@conduit:matrix.skylake.mihaly.codes` admin room. See `modules/nixos/matrix/` |

The public Homer board lists the public services (it-tools, public files,
ntfy, matrix); the private Homer board (on the tailnet) lists the rest.

## Tailnet

`http://skylake.anaconda-snapper.ts.net/` redirects to `/homer` — the
**private** Homer instance (port 8080, `SUBFOLDER=/homer`). The other
service ports (deluge, paperless, immich, it-tools, private copyparty,
homer, homer-public) are only reachable from the `tailscale0` interface.

## How the apex works

- `mkService` (lib/nixos/default.nix) has an `apex` flag: with
  `apex = true` the public vhost becomes nginx's `default_server`, so the
  bare domain falls into it. Only one service per machine may claim the
  apex — nginx refuses to start with two default servers on the same
  listen socket.
- The Let's Encrypt cert for a vhost covers `serverName + serverAliases`.
  `apex = true` also adds the bare domain to `serverAliases`, so the
  `homer-public` cert includes **both** `homer-public.skylake.mihaly.codes`
  and `skylake.mihaly.codes` (lego: `-d homer-public... -d skylake...`).
  Without this, the apex would serve a hostname-mismatched cert.
- The public instance is defined by the shared builder in
  `modules/nixos/homer/default.nix` via `modules.homer.public`
  (container `homer-public`, port 8081, no SUBFOLDER — served at root).
  The private instance (`modules.homer.enable`) is unchanged.

## Certificates (Let's Encrypt, HTTP-01 via webroot)

- `homer-public.skylake.mihaly.codes` + `skylake.mihaly.codes` (one cert)
- `it-tools.skylake.mihaly.codes`
- `files.skylake.mihaly.codes`
- `ntfy.skylake.mihaly.codes`
- `matrix.skylake.mihaly.codes`
- Account: `mihaly@mihaly.codes`

First activation with a new cert name orders a new certificate; until
then nginx runs with a self-signed fallback. The webroot
`/var/lib/acme/acme-challenge` is created/healed by a version-agnostic
tmpfiles rule (`d`/`z`, processed before the acme module's own rule) —
see the comment in `mkService` for the 2026-08-23 incident it fixes.

## Deploy

    make skylake        # or: deploy -s .#skylake

Watch `systemctl status acme-order-renew-homer-public.skylake.mihaly.codes`
after activation for the first certificate order.
