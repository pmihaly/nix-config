# Skylake public access — progress

Goal: make some services publicly accessible via the new DNS records
(`skylake.mihaly.codes`, `*.skylake.mihaly.codes` → `157.180.77.226`),
while keeping the rest Tailscale-only.

## Status

- [x] Investigate current setup (mkService, nginx, tailscale, firewall)
- [x] Answer: does nginx basic auth support SSO? → **No**
- [x] Audit current public exposure of `157.180.77.226`
- [x] Add `publicDomainName` + `acmeEmail` to skylake vars
- [x] Fix `mkService` silent-drop bug (`//` vs `mkMerge`)
- [x] Extend `mkService` (lib/nixos/default.nix) with `public` flag + tailnet-only firewall
- [x] Make `it-tools` public (no auth — static dev tools site, HTTPS + Let's Encrypt)
- [x] Close the accidental world exposure of the other services
- [x] Validate config (`nix build .#nixosConfigurations.skylake.config.system.build.toplevel`
      + inspecting the generated nginx.conf, firewall-start script and ACME units)
- [ ] Deploy: `make skylake`
- [ ] Verify post-deploy: `https://it-tools.skylake.mihaly.codes` reachable from outside
      the tailnet (cert issued, app served); other ports closed from outside,
      still reachable via tailnet (e.g. from aesop)

## The SSO question (decision: stop basic auth)

**nginx basic auth cannot support SSO.** HTTP Basic auth is just a base64
username/password re-sent on every request: no sessions, no tokens, no
OAuth2/OIDC/SAML flow, no identity provider integration. SSO requires an
auth *protocol* (OIDC/OAuth2 or SAML), which means a proxy in front (e.g.
oauth2-proxy / Authelia / Keycloak), not nginx `basicAuth`.
→ Per instruction, the basic-auth plan is dropped.

## ⚠️ Security finding: services were ALREADY exposed to the internet

"Protected by tailscale" was only true at the DNS level (the
`*.ts.net` name doesn't resolve outside the tailnet). `mkService` put every
service port into `networking.firewall.allowedTCPPorts`, which is open to
**any** source. Port scan of the public IP on 2026-08-24 (from aesop):

| port  | service   | state before |
|-------|-----------|--------------|
| 80    | nginx     | OPEN (301 to /homer, harmless) |
| 443   | -         | closed |
| 8080  | homer     | OPEN |
| 8088  | it-tools  | OPEN (static site, no data) |
| 8096  | jellyfin  | OPEN (media server) |
| 2283  | immich    | OPEN (photos) |
| 28981 | paperless | OPEN (documents) |
| 3210  | copyparty | OPEN — **anonymous access `A = "*"` to the whole root fs, incl. delete+admin** |
| 3000/8081/8888 | local-llm | not enabled on skylake |
| 8112  | deluge    | OPEN (web UI) |

Copyparty anonymous access was the critical one (anyone could browse/delete
files on skylake).

## ⚠️ Root cause of "the firewall rules never appeared": a silent mkService bug

`mkService` built its config as `base // lib.mkIf cond { ... } // ...`. The
shallow `//` merge copies the `mkIf` wrapper's *wrapper* attributes
(`_type = "if"`, `condition`, `content`) into the top level of the result,
on top of `base`'s plain options. The module system's `pushDownProperties`
then sees a top-level `_type`/`condition`/`content` and treats the **entire**
service config as a single conditional wrapper — when the condition was
false it kept only `content` and **silently discarded the whole `base`**
(firewall rules, tailnet vhost redirect, homer entry). No error, no
warning: the firewall rules for every mkService-based service were simply
never emitted, which is why the ports were world-open instead of
tailnet-only.

Fix: build the three parts as separate attrs and combine with
`lib.mkMerge [ base dashboardConfig publicConfig extraConfig ]` (the same
pattern `local-llm` already used). Verified in the built firewall-start
script: all 7 service ports get `ip46tables -A nixos-fw -i tailscale0 -p
tcp --dport N -j nixos-fw-accept`, placed after the world-allow rules (22/80/443)
and before the final `nixos-fw-log-refuse`.

## How the tailnet restriction works

- Service ports are removed from `networking.firewall.allowedTCPPorts`
  (which accepts **any** source and is evaluated first).
- Instead, each port gets an interface-scoped accept rule on `tailscale0`
  via `networking.firewall.extraCommands` (iptables backend) /
  `extraInputRules` (nftables backend; both are defined, each backend
  applies its own). Matching the interface (not the `100.64.0.0/10` source
  range) covers the IPv4 CGNAT range and any ULA prefix.
- Loopback is trusted by the firewall, so nginx can proxy to the service
  port on `127.0.0.1`.
- `public = true` adds an nginx vhost `${subdomain}.${publicDomainName}`:
  HTTP-01 ACME (Let's Encrypt) webroot at `/var/lib/acme/acme-challenge`,
  `forceSSL`, and `proxy_pass http://127.0.0.1:<port>`. The service port
  itself stays tailnet-only.

## Evaluation quirk: forcing the whole `security.acme` attrset throws

Forcing `config.security.acme` *as a whole* (e.g. `builtins.toJSON
c.security.acme`) fails with "option `security.acme.activationDelay` can no
longer be used since it's been removed" — nixpkgs declares removed options
with an unconditional `apply = throw`, and whole-attrset forcing evaluates
every declared sub-option, removed ones included. Nothing in the build,
activation or deploy path forces the whole attrset (they touch specific
sub-attributes only), so this is a verification-script artifact, not a
deploy blocker. `nix build ...toplevel` succeeds.

## Changes

1. `machines/skylake/vars.nix` — add `publicDomainName =
   "skylake.mihaly.codes"` and `acmeEmail`.
2. `lib/nixos/default.nix` (`mkService`):
   - **fix** the `//`/`mkIf` silent-drop bug (now `lib.mkMerge`).
   - firewall: service ports no longer world-open; tailnet-only via
     interface-scoped `extraCommands`/`extraInputRules`.
   - new `public ? false` arg: nginx vhost on the public domain with ACME
     TLS + loopback proxy, plus `security.acme` account setup.
3. `modules/nixos/it-tools/default.nix` — `public = true`.
4. `modules/nixos/deluge/default.nix` — web UI (`openFirewall = false`) is now
   tailnet-only via mkService; port 6881 (peer traffic) stays world-open, that's
   inherent to torrenting.
5. `modules/nixos/jellyfin/default.nix` — drop world-open UDP 7359 (SSDP
   discovery; pointless on a server).

## Follow-ups (not done)

- Copyparty `A = "*"` anonymous access should be replaced with real auth
  (it's tailnet-only now, but anonymous is still a bad habit).
- Real SSO story if wanted later: Authelia or oauth2-proxy in front of nginx
  with an OIDC provider.
- The first public service is also the `default_server` on 80/443, so the
  apex `skylake.mihaly.codes` currently serves it-tools (and `nginx -t`
  fails loudly if a second public vhost is added without deciding the
  default). Decide what should live at the apex.
- Immich/paperless/jellyfin credentials are weak; worth rotating since the
  apps were exposed for a while.
