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
- [x] Diagnose it-tools serving a self-signed (minica) cert — root cause found
      (webroot dir never created on the live system despite the acme module's
      tmpfiles rule: spurious tmpfiles failure + first-activation mount race;
      see below), fixed via tmpfiles
- [x] **Resolve the nixpkgs lock mismatch** (committed lock root was a stale
      `NixOS/nixpkgs/nixpkgs-unstable` entry that never matched flake.nix, so
      `make update` never updated it; deployed system ran 26.11) — root input
      re-locked to `nixos/nixpkgs/nixos-unstable` @ `56c02bc` (2026-08-23, 26.11)
- [x] Hardening: IPv4 `FORWARD` policy `DROP` (+ tailnet/lo/established allows)
      so podman-published ports are not reachable from the WAN even though the
      NixOS INPUT firewall doesn't see forwarded traffic
- [x] Deploy (deploy-rs needs an interactive sudo password, so the manual
      non-interactive equivalent was used: `nix copy` the closure as root over ssh
      + `switch-to-configuration switch`)
- [x] Verify post-deploy (2026-08-24, from aesop): `https://it-tools.skylake.
      mihaly.codes` → 200 with the real Let's Encrypt cert (ssl_verify=0),
      HTTP 301→HTTPS; WAN probes: 8096/2283/8080 **blocked**, 443/80 open;
      tailnet probes (100.69.8.15): 8096/2283/28981/8112/8080/3210/22 all
      open; `iptables -S FORWARD`: policy DROP + the 3 allow rules; container
      egress verified (podman exec fetch of api.github.com → 200); all services
      active
- [x] Persist FORWARD hardening across reboots: the firewall module silently
      dropped `extraCommands` (see root-cause section below) → dedicated
      `fw-forward` oneshot unit; rules were also applied live by hand on
      2026-08-24 before the unit landed
- [x] One-time ACME bring-up (done 2026-08-24 on the live system, pre-deploy):
      `systemd-tmpfiles --create /etc/tmpfiles.d/10-acme.conf` created the webroot,
      `systemctl start acme-order-renew-it-tools...` then obtained a **real Let's
      Encrypt cert** (issuer `CN=YE2`, `acme-success` touched, nginx serves it,
      `HTTP/2 200` from the public IP) — the whole ACME flow is verified working

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

## ⚠️ Root cause: it-tools served a minica self-signed cert (ACME never succeeded)

Symptom: `https://it-tools.skylake.mihaly.codes` presented a minica
self-signed certificate; the `acme-order-renew-*` unit failed daily with
`webroot path does not exist` (lego `--http.webroot /var/lib/acme/acme-challenge`).

Causal chain (all verified against the live system + the built config):

1. The nginx vhost is correct: the port-80 server has
   `location ^~ /.well-known/acme-challenge/ { root /var/lib/acme/acme-challenge; }`
   (plus the 443 server and the proxy to 127.0.0.1:8088). Nothing wrong in
   our config.
2. `security.acme.certs."it-tools...".webroot` = `/var/lib/acme/acme-challenge`
   (wired by the nginx module from the vhost's `acmeRoot`), `group = nginx`,
   `email` set. Config is fine.
3. But `/var/lib/acme/acme-challenge` **did not exist on disk** (the cert
   dir, `.lego`, `.minica` did).
4. Why — corrected after live inspection (the first hypothesis, "nixpkgs 26.11
   removed webroot creation", was **wrong**):
   - The acme module **does** ship the webroot tmpfiles rule: `10-acme.conf`
     with `d /var/lib/acme/acme-challenge` (+ `.well-known/...`) as
     `acme:acme` 0755 — **identical in the deployed f13ff45 build and the new
     56c02bc build** (verified by diffing the built `/etc/tmpfiles.d`).
   - Every **full** `systemd-tmpfiles --create --remove --exclude-prefix=/dev`
     run on skylake (both `systemd-tmpfiles-setup` at boot and
     `systemd-tmpfiles-resetup` at activation) **exits 73** with
     `Failed to extract filename from path '/': Cannot assign requested
     address` — a spurious error (no rule references `/`). Empirically it
     still applies all rules (verified: `rm -rf` the webroot, full run →
     recreated), so this is not fatal by itself — but it means every
     boot/activation logs a tmpfiles failure.
   - The webroot was nevertheless missing even after two such runs (boot
     00:23, activation 10:37 — both at the same second as the `var-lib-acme`
     mount / minica bootstrap creating `/var/lib/acme`). Most likely a
     **first-activation ordering race** (tmpfiles `d`-rule vs the `/var/lib/acme`
     mount coming up; skylake's root is tmpfs and `/var/lib/acme` is a
     persisted mount, so a directory created under the unmounted path is
     hidden once the mount lands).
   - Once the mount was stably up, a targeted
     `systemd-tmpfiles --create /etc/tmpfiles.d/10-acme.conf` created the webroot
     (exit 0), and the very next `systemctl start acme-order-renew-...` **succeeded**:
     real Let's Encrypt cert (issuer `CN=YE2`), `acme-success` touched, nginx
     reloaded with it, `HTTP/2 200` from the public IP.
5. Meanwhile (before the fix) the minica bootstrap unit kept running (its exit
   condition is `out/acme-success`, which only a *successful* lego run
   touches), so nginx kept serving the self-signed cert.

Fix (in this commit): `mkService`'s `public` config now adds tmpfiles rules
`d /var/lib/acme/acme-challenge 0750 acme nginx -` + a `z` line (create if
missing; fix mode/owner if present — idempotent, self-healing after a
/persist rebuild, survives the tmpfs root). `users.mutableUsers = false` →
static `/etc/passwd`, so the `acme`/`nginx` names resolve when
systemd-tmpfiles-setup runs early at boot. lego runs as `User=acme
Group=nginx UMask=0022`, so challenge tokens are `acme:acme 0644` (world-
readable via the `o+r` bit) and readable by nginx workers regardless of
which rule created the directory first. This rule is **version-agnostic
belt-and-suspenders**: it lives in `00-nixos.conf` (processed before the
acme module's `10-acme.conf`), so even if the upstream rule ever disappears
or the mount race recurs, the webroot is recreated at every boot and its
ownership is healed to `acme:nginx 0750` (nginx group can read the tokens).

One-time bring-up (already done 2026-08-24 on the live system, before the
deploy — no need to repeat after it):
```sh
systemd-tmpfiles --create /etc/tmpfiles.d/10-acme.conf   # created the webroot
systemctl start acme-order-renew-it-tools.skylake.mihaly.codes.service
# result: real LE cert (CN=YE2), acme-success touched, nginx serves it,
# HTTP/2 200 from the public IP
```

## ✅ Resolved: lock mismatch — committed lock was stale, deployed system ran 26.11

Facts (all verified):

- Committed `flake.lock`: root `nixpkgs` node = **`NixOS/nixpkgs` @ ref
  `nixpkgs-unstable`**, locked `47472570b` (2026-02-02, 26.05 era).
- `flake.nix` (in every commit of this repo's history) declares the root
  input as **`github:nixos/nixpkgs/nixos-unstable`** — lowercase owner,
  `nixos-unstable` ref. The committed lock's root node matches **no**
  version of flake.nix; it is a stale entry (likely carried over from a
  pre-history-rewrite lockfile).
- The deployed system (gen 53, deployed 2026-08-24) and the local `result/`
  are the same store path:
  `nixos-system-skylake-26.11.20260807.f13ff45` — built from nixpkgs
  **f13ff45 (2026-08-07, 26.11 era)**, i.e. the build was done from a
  working-tree lock whose root *had* been updated, later reverted.

Why the staleness persisted (the interesting part):

- `update.nu` (`make update`) runs `nix flake lock --update-input <name>`
  per input. Because the lock's root `original` (`NixOS/nixpkgs
  nixpkgs-unstable`) differs from flake.nix's declared input
  (`nixos/nixpkgs nixos-unstable`), `nix flake lock --update-input
  nixpkgs` does **not** update the root input — it matches a *nested*
  `nixpkgs` input instead (reproduced 2026-08-24: it updated `nixpkgs_8`,
  a nested `nixos/nixpkgs@nixos-unstable` pin, and left the root at
  `47472570`). Every `make update` since 2026-02-02 silently skipped the
  root nixpkgs.

Fix applied (this commit): hand-rewrote the root `nixpkgs` node in
`flake.lock` to match flake.nix — `nixos/nixpkgs` @ `nixos-unstable`,
locked to `56c02bc` (2026-08-23, the current branch tip at the time,
**26.11 era**). That is the direction the system is already running (the
deployed build was f13ff45 / 2026-08-07, same 26.11 cycle), so the delta
is ~16 days of nixpkgs, not a minor-release jump. Verified after the edit:
`nix flake metadata` is clean, `nixosConfigurations.skylake` evaluates
with `system.nixos.release = "26.11"`.

Note for the future: `make update` will now actually update the root
input (flake.nix and the lock agree), so the root nixpkgs will track
nixos-unstable on the next `make update`. (The ACME webroot rule has been
present in the acme module across these revisions — the live failure was
the tmpfiles execution/mount race documented above, not a removed rule —
and the `mkService` tmpfiles fix is version-agnostic belt-and-suspenders.)

## Evaluation quirk: forcing the whole `security.acme` attrset throws

Forcing `config.security.acme` *as a whole* (e.g. `builtins.toJSON
c.security.acme`) fails with "option `security.acme.activationDelay` can no
longer be used since it's been removed" — nixpkgs declares removed options
with an unconditional `apply = throw`, and whole-attrset forcing evaluates
every declared sub-option, removed ones included. Nothing in the build,
activation or deploy path forces the whole attrset (they touch specific
sub-attributes only), so this is a verification-script artifact, not a
deploy blocker. `nix build ...toplevel` succeeds.

## ⚠️ Root cause of the world exposure: podman published ports bypass the INPUT firewall

`mkService`'s ports went into `networking.firewall.allowedTCPPorts` →
world-open INPUT accepts (see above). But even after scoping them to
tailscale0, a second exposure remained: the podman-published ports
(jellyfin 8096, homer 8080, immich 2283, ...).

- netavark implements `podman -p host:container` with **DNAT** in the
  `nat` table (PREROUTING → DNAT to the container IP on `podman0`).
- A packet hitting a published host port from the WAN is therefore
  **forwarded** traffic (WAN in, bridge out) — the `nixos-fw` INPUT chain
  is never consulted for it.
- NixOS leaves the `FORWARD` policy at **ACCEPT**, and neither the NixOS
  firewall nor netavark's `NETAVARK_FORWARD` chain has any rule covering
  WAN→published (that chain only drops INVALID, accepts established and
  bridge-originated egress). Verified live 2026-08-24: `:FORWARD ACCEPT`
  with a growing accept counter (WAN scan traffic), and the tailscale
  `ts-forward` chain (explicit accepts) is the only other rule.

Fix (`use-cases/server/default.nix`, iptables `extraCommands`):

```sh
iptables -D FORWARD -i tailscale0 -j ACCEPT ...        # idempotency preamble
iptables -D FORWARD -i lo -j ACCEPT ...
iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT ...
iptables -A FORWARD -i tailscale0 -j ACCEPT            # tailnet → published ports
iptables -A FORWARD -i lo -j ACCEPT                     # locally generated, DNATed to a container
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -P FORWARD DROP                                # WAN → published: silent drop
```

Why each piece is needed / safe:

- **tailscale0**: tailnet clients must keep reaching published ports
  (`ts-forward` already accepts them; the explicit rule makes it
  self-documenting and keeps working if the tailscale module's rules
  change).
- **lo**: locally generated traffic whose destination is DNATed to a
  container (host services talking to published ports on 127.0.0.1)
  arrives at FORWARD with `iif=lo`. Loopback cannot be spoofed from
  outside, and with a DROP policy such packets can only end up on the
  podman bridge (nothing DNATs lo traffic to the WAN or the tailnet).
- **RELATED,ESTABLISHED**: return traffic for all of the above and for
  container egress.
- **IPv4 only, deliberately**: the IPv6 `FORWARD` policy stays ACCEPT.
  The podman bridge relies on IPv6 NDP/multicast flows, and tailscale
  v6 forwarding goes through FORWARD; a blanket v6 drop is not worth the
  risk, and the v6 exposure is mitigated anyway by Hetzner not
  advertising the host to the v6 internet in practice (revisit if the
  bridge ever gets a public v6 route).
- **Container egress unaffected**: netavark inserts `NETAVARK_FORWARD`
  at the **head** of `FORWARD` on every container start (re-adding it if
  activation wiped it), and it accepts `-s <bridge-subnet>`
  unconditionally — before any of the rules above are evaluated.
- **Idempotent**: `firewall-start` never flushes the built-in `FORWARD`
  chain on a system switch, so the three `-D ... || true` preambles
  remove the previous generation's rules before re-adding them (run
  under `bash -e`, hence the `|| true`).
- **Caveat**: `extraCommands` only takes effect with the iptables
  firewall backend (the default, and what skylake runs). If the backend
  is ever switched to `nftables`, this needs porting to
  `networking.nftables` (or an activation script).

After the change, from the WAN only 22/80/443 remain reachable (nginx
world rules); every podman-published port is a silent DROP, and
established connections survive (policy DROP only affects the
first packet of a flow).

## ⚠️ Second silent drop: the firewall module ignores `extraCommands` (nixos-unstable @ 56c02bc)

Symptom: the FORWARD rules above were set in the evaluated config (`nix eval
…config.networking.firewall.extraCommands` shows all seven iptables lines),
yet the generated `unit-firewall.service` kept the **exact same store hash**
(`sjgp5aks35fwncdpqj34djkdr6i83j98`) as generations built *before* the rules
were added — none of the lines ever reached the unit. The live FORWARD chain
stayed `-P FORWARD ACCEPT` after the deploy, leaving the podman-published
ports world-reachable until the rules were applied by hand (2026-08-24).

Same class of silent drop as the mkService bug (cce82a7): option set,
evaluation looks correct, the mechanism that is supposed to materialise it
quietly doesn't. The exact module-side cause was not pinned down (the
56c02bc firewall module's iptables unit generation is the suspect; the
module is no longer in the local source checkout at a matching rev), so the
fix does not depend on it:

Fix (`use-cases/server/default.nix`): a dedicated `fw-forward` oneshot unit
(applies the same idempotent rule set, `After=firewall.service`,
`WantedBy=sysinit.target`, `RemainAfterExit`). A plain systemd unit cannot be
dropped by a firewall-backend quirk, and it shows up in `systemctl` like
anything else. The `extraCommands` copy is kept too: harmless if the module
keeps dropping it (the `-D` preambles make double application idempotent),
and it becomes redundant-but-correct if a future nixpkgs honours it.

Restart safety (verified against the unit's scripts): `firewall-stop` only
removes the `nixos-fw`/`nixos-drop` rules and never touches the FORWARD chain
or policy, and `firewall-start` never flushes FORWARD either — so the rules
survive firewall restarts across system switches; they are re-applied at
boot (sysinit, right after `firewall.service`).

## Changes

1. `machines/skylake/vars.nix` — add `publicDomainName =
   "skylake.mihaly.codes"` and `acmeEmail`.
2. `lib/nixos/default.nix` (`mkService`):
   - **fix** the `//`/`mkIf` silent-drop bug (now `lib.mkMerge`).
   - firewall: service ports no longer world-open; tailnet-only via
     interface-scoped `extraCommands`/`extraInputRules`.
   - new `public ? false` arg: nginx vhost on the public domain with ACME
     TLS + loopback proxy, plus `security.acme` account setup.
   - tmpfiles rules creating/healing the ACME HTTP-01 webroot on every
     boot (version-agnostic defense in depth against the mount race /
     tmpfiles failure documented in "Root cause: it-tools served a minica
     self-signed cert").
3. `use-cases/server/default.nix` — IPv4 `FORWARD` hardening (policy `DROP`
   + tailnet/lo/established allows) so podman-published container ports are
   not reachable from the public internet (see "Root cause of the world
   exposure" above). Applied via a dedicated `fw-forward` oneshot unit
   (the firewall module silently drops `extraCommands` in the locked
   nixpkgs; the `extraCommands` copy is kept as belt-and-suspenders — see
   "Second silent drop" above).
4. `flake.lock` — root `nixpkgs` re-locked to
   `nixos/nixpkgs@nixos-unstable` `56c02bc` (2026-08-23, 26.11 era),
   matching flake.nix and the deployed system's release line (see
   "Resolved: lock mismatch").
5. `modules/nixos/it-tools/default.nix` — `public = true`.
6. `modules/nixos/deluge/default.nix` — web UI (`openFirewall = false`) is now
   tailnet-only via mkService; port 6881 (peer traffic) stays world-open, that's
   inherent to torrenting.
7. `modules/nixos/jellyfin/default.nix` — drop world-open UDP 7359 (SSDP
   discovery; pointless on a server).

## Follow-ups

- Copyparty anonymous access — resolved by the 2026-08-25 rework: the public
  instance is an rwmd share of a single directory and the private instance is
  tailnet-only behind a password, so the old `A = "*"` root-fs exposure is
  gone.
- Real SSO story if wanted later: Authelia or oauth2-proxy in front of nginx
  with an OIDC provider.
- Apex default_server — resolved: the apex now serves copyparty-public (the
  `files.<publicDomain>` vhost is also the default server), not it-tools.
- Immich/paperless credentials are weak; worth rotating since the
  apps were exposed for a while.
