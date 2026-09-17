Status: approved spec for the "void directory" feature on the copyparty module.

Author of record: task t_58f80ade (planner). Downstream: backend / frontend cards gated on this task.

Scope: definition, config, file-operation semantics, edge cases, acceptance criteria.

## 1. Definition

A **void directory** is a directory on the **public** copyparty instance

(`https://files.<publicDomain>/void`) that behaves as a **one-way black hole**

for anonymous visitors:

- **Upload (write): ALLOWED.** Anyone can PUT/POST new files into it.

- **Read (list, download, metadata): DENIED.** Visitors cannot see or fetch

  what is in it.

- **Move / delete / rename: DENIED.**

Files dropped into the void become \*\*normally visible and manageable on the

**private** instance\*\* (the whole-filesystem, password-protected share). The

private operator is the only party that can list, download, or curate/delete

the contents.

Why it is called a _void_: from the public side you can throw files in, but you

can never see them back out or remove them. The pubic side is strictly

write-only; the private side owns the lifecycle.

## 2. Ground truth: native support, no source patch required

copyparty supports **write-only volumes** out of the box. Volume `accs:`

are per-volume, and a volume that grants only `w` allows upload but not

browse/download of its contents (upstream README, "write-only folders"

semantics).

Permission letters (used below):

- `r` = browse / list / download

- `w` = write / upload (also move/copy _into_)

- `d` = delete / move-out

- `m` = move

- `a` = admin

Therefore **no change to pkgs.copyparty or any copyparty source is needed**.

This is a configuration change to the copyparty NixOS module only. Any

downstream task that assumed a copyparty source patch or that the void

"prevents uploads" is operating on the **inverted** model: the void _permits_

uploads and _denies_ reads.

## 3. Current config (exact anchors)

File: `modules/nixos/copyparty/default.nix`

- `storage = vars.storage`

- `publicConf` (≈ lines 126–155): `[/]` → `${storage}/Public`, `accs: rwmd: *`,

  flags `d2t,e2d,maxb: 10g,300, maxn: 250,600, scan: 60, vmaxb: 100g, vmaxn: 100k`,

  `hist: ${storage}/Services/copyparty-public-hist`; plus `[/plug]` → `${plugDir}`, `r: *`.

- Public unit `preStart` (≈ lines 225–235): `install -d` of the volume root

  and XDG + hist dirs (`${storage}/Public`, `${storage}/Services/copyparty-public`,

  `-public-hist`, `-public-plug`).

- tmpfiles `d` rules (≈ lines 176–183) as the boot-time self-healing safety net.

- `restartTriggers = [ publicConf ]` — editing `publicConf` auto-restarts the

  public unit on deploy. No new trigger needed.

## 4. Design decision (owned by this spec)

Mount the void as its own **top-level volume** on the public instance:

```ini

[/void]

${storage}/Void

accs:

w: *

flags:

d2t

e2d

maxb: 10g,300

maxn: 250,600

scan: 60

vmaxb: 100g

vmaxn: 100k

hist: ${storage}/Services/copyparty-public-void

```

### 4.1 Placement rule — CRITICAL

`${storage}/Void` **MUST be a sibling of** `${storage}/Public`, \*\*not a

subdirectory of it.\*\*

Reason: the public root volume `[/]` maps `${storage}/Public` with

`accs: rwmd: *` for everyone. If the void lived at `${storage}/Public/void`,

that root volume would also match the `/void` URL and grant anonymous

`rmwd` — a full **read-leak**. Keeping the real directory outside `${storage}/Public`

means **no volume overlaps** `/void`; the only volume that serves that URL is the

write-only one, so a leak is _structurally impossible_. This sidesteps any

nested-volume-precedence edge and mirrors the existing `[/plug]` sibling-volume

pattern.

### 4.2 Wired-in changes (backend card work)

1. `publicConf`: add the `[/void]` block from §4.

2. Public unit `preStart` (after the `${storage}/Public` install line):

   ```

   install -d -m 0755 -o copyparty -g copyparty ${storage}/Void

   install -d -m 0700 -o copyparty -g copyparty ${storage}/Services/copyparty-public-void

   ```

   The unprivileged `copyparty` user cannot create these under the root-owned

   parent, and tmpfiles may run after this unit — so preStart must create them

   (same rationale as the existing block).

3. tmpfiles rules add:

   ```

   d ${storage}/Void 0755 copyparty copyparty -

   d ${storage}/Services/copyparty-public-void 0700 copyparty copyparty -

   ```

**No change** to the private unit or `privateConf`: the private instance already

serves all of `${storage}` (root volume `/`) with full perms on login, and its

`e2d scan: 60` picks up new uploads. Both instances run as the same `copyparty`

OS user, so ownership on `/persist` is consistent.

**No nginx change**: the public vhost proxies `127.0.0.1:3211` wholesale;

`/void` flows through automatically.

## 5. Behavior matrix

### Public instance (anonymous, at /void)

| Operation | Result |

| -------------------------- | ---------------------------------------------------------- |

| Upload (POST new file) | ALLOWED (`w`) → lands at `${storage}/Void/<name>` |

| Browse / list contents | DENIED (no `r`) — no entries visible |

| Download a known filename | DENIED (no `r`) |

| Delete / move / rename | DENIED (no `d`/`m`) |

| Overwrite an existing name | Not granted (create-only `w`); verify + document at deploy |

| Undo / unpost own upload | Not available to anon — acceptable for a void |

The `/void` mount appears in the public UI root listing as a volume the

visitor **cannot open** — this is desired: a discoverable, share-URLs void

target (exactly upstream write-only-folder behavior). It does NOT appear as

contents.

### Private instance (operator, logged in)

`${storage}/Void` sits under the private root `/` volume → fully browsable,

downloadable, deletable with the account's full perms. `d2t/e2d` indexing

picks uploads up within `~scan: 60`s.

## 6. Edge cases

- **Empty before first upload**: a share with no _visible_ files shows

  copyparty's plain-text info page even to browsers (full UI appears after the

  first file exists) — cosmetic, upstream behavior; acceptable.

- **Disk exhaustion**: the void writes to `/persist` (250G) like the main pool;

  the `vmaxb`/`vmaxn` volume caps and `maxb`/`maxn` per-client burst caps in §4

  bound it. Tune if the void volume needs a tighter ceiling.

- **Filename collisions**: two visitors uploading the same name — verify

  copyparty's default (suffix/reroute) at deploy; document chosen behavior.

- **Dangerous/oversized content**: uploads are stored inert (no server-side

  execution); served with correct MIME. Operator curates/removes on private.

  Opt-in hardening (extension allow-list, overwrite ban) is out of scope unless

  requested.

- **hist isolation**: every volume needs its own `hist:` (copyparty forbids

  sharing one). The void gets an explicit external hist dir

  (`${storage}/Services/copyparty-public-void`, 0700 copyparty-owned) so no

  index/undo metadata lives inside the anonymously-writable directory.

- **Instance mismatch**: none — same `copyparty` OS user, same `/persist`

  mount on both instances.

## 7. Acceptance criteria (backend card must verify on the live box after deploy)

1. Anonymous upload: `curl -F 'f=@<file>' https://files.<publicDomain>/void`

   → non-4xx (created); file exists at `${storage}/Void/<name>` on disk.

2. Anonymous read blocked: GET `https://files.<publicDomain>/void` shows **no**

   file entries; GET `.../void/<name>` → 403/denied.

3. Anonymous delete/move blocked: DELETE / rename on `.../void/<name>` → denied.

4. Private operator: log in, browse `${storage}/Void` → file present,

   downloadable, deletable.

5. Cross-instance: a file uploaded via public `/void` appears on the private

   instance within ~60 s (e2d scan).

## 8. Out of scope / follow-ups

- **No copyparty source patch** — explicitly do not modify `pkgs.copyparty` /

  upstream; this is module config only.

- **Frontend / share panel** (frontend card): optionally surface a "Void"

  link pointing at `https://files.<publicDomain>/void`. Nothing to hide — the

  void is a separate volume and is not part of the main-pool listing.
