# copyparty module — upgrading & patch maintenance

This module runs a **patched** copyparty (see `patches/video-tracks.patch`)
plus a self-contained browser plugin (`video-tracks.js`) that provides
in-browser video playback with audio/subtitle track selection via the
patched server's `?th=` conversion endpoint.

## Layout

| File                                | Purpose                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `pin.json`                          | Pinned sdist: URL + version + sha256 (base64). **The** upgrade point.                                                     |
| `package.nix`                       | Vendored from upstream `contrib/package/nix`, minus the git/unstable branch; adds `patches`.                              |
| `overlay.nix`                       | Puts the patched copyparty (and its `partftpy` dep) on the NixOS build path.                                              |
| `patches/`                          | `video-tracks.patch` — server-side patch (`diff -ruN a/ b/`, applied with `-p1`).                                         |
| `video-tracks.js`                   | Browser plugin, served read-only via the `[/plug]` volume. No coupling to copyparty internals beyond the `?th=` HTTP API. |
| `default.nix`                       | NixOS module: `copyparty-public` / `copyparty-private` units, nginx vhosts, persistent dirs.                              |
| `partftpy.nix`, `partftpy-pin.json` | FTP server dep (also patched, see below).                                                                                 |

## The `?th=` contract (what the plugin relies on)

- `GET <file>?th=json` — track metadata (audio/subtitle/video streams).
- `GET <file>?th=mp4[:N]` — MP4 remux, audio track N; one-time
  server-side conversion, cached under `<histpath>/vr/...`.
- `GET <file>?th=vtt:N` — subtitle track N as WebVTT.
- Conversions keep running after the client disconnects; a second client
  for the same file/track waits for the first (waiting room).
- Workers = `--th-mt` (default: CPU cores) → parallel conversions.

**If you change the conversion/codec policy in the patch, bump
`VR_POLICY` in `th_srv.py`** — it is part of the VR cache key. Otherwise
old cached files (e.g. EAC-3-in-MP4 that phones can't decode) keep being
served. Orphaned old cache entries are swept by copyparty's cleaner after
`--vr-maxage` (default 1 day).

Current policy: audio codecs `aac`/`mp3` are stream-copied; everything
else (eac3, ac3, flac, alac, opus, ...) is transcoded to AAC 192k —
phones cannot decode E-AC-3/AC-3/ALAC in MP4.

## Upgrading copyparty (bumping the pin)

1. Pick a release: <https://github.com/9001/copyparty/releases>.
   Check the changelog for changes to `th_srv.py`, `web/` (especially
   `browser.js` — the plugin replaces MPlayer's `(🎧)` link in the DOM and
   breaks if that changes), and the `--th-*` flags.
2. Compute the hash and update `pin.json`:
   ```sh
   curl -fLO https://github.com/9001/copyparty/releases/download/v<VER>/copyparty-<VER>.tar.gz
   nix hash file --to base64 copyparty-<VER>.tar.gz   # -> "hash" in pin.json
   ```
3. Build. stdenv applies the patch **before** building — a broken patch
   fails the build, you cannot deploy a half-patched copyparty:
   ```sh
   nix build .#nixosConfigurations.skylake.config.system.build.toplevel
   ```
4. If the patch applied cleanly: deploy and smoke-test (play a video with
   2+ audio tracks on a phone, check `journalctl -u copyparty-public`).
   If it failed: regenerate the patch, see below.
5. `make skylake`

**The patch is the only thing that can break on a bump.** The plugin JS is
version-independent (it only uses the `?th=` API and the list-row DOM).
Note: phones may keep an old copy of the plugin in their browser cache —
after a plugin change, hard-refresh (or close the tab) to verify.

## Regenerating the patch (after a failed bump)

The patch is a plain `diff -ruN a/copyparty/... b/copyparty/...` of the
pristine sdist tree vs the patched tree. Regeneration:

```sh
V=<VER>
# the sdist root is versioned (copyparty-$V/); the patch paths are relative
# to it, so keep the python package (copyparty-$V/copyparty) as the tree:
mkdir -p /tmp/cpbump/a /tmp/cpbump/b
curl -fLO https://github.com/9001/copyparty/releases/download/v$V/copyparty-$V.tar.gz
tar -xf copyparty-$V.tar.gz
cp -a copyparty-$V/copyparty /tmp/cpbump/a/copyparty
cp -a copyparty-$V/copyparty /tmp/cpbump/b/copyparty

# see what applies and what doesn't:
cd /tmp/cpbump
patch -p1 -d b --dry-run < ../../modules/nixos/copyparty/patches/video-tracks.patch
```

For each hunk that fails, re-apply it by hand in `b/copyparty/...`
(read the surrounding upstream code; the patch is additive — new
`vrc`/`th_vrc_convt` volflags, the `?th=` dispatch in `th_srv.py`,
`VR_POLICY`, the audio-copy policy — so conflicts are usually "context
moved or renamed", not "feature deleted").

Then regenerate and verify:

```sh
cd /tmp/cpbump
diff -ruN --no-dereference a b > <repo>/modules/nixos/copyparty/patches/video-tracks.patch

# sanity: the patched tree must now build
nix build .#nixosConfigurations.skylake.config.system.build.toplevel

# sanity: the patched files must equal what the build produced
# (store path of the running package, e.g. from `systemctl cat copyparty-public`)
diff /tmp/cpbump/b/copyparty/th_srv.py \
     /nix/store/<copyparty-store-path>/lib/python3*/site-packages/copyparty/th_srv.py
```

### Gotchas

- **`diff -ruN` without `--no-dereference` fails with noise**: the sdist
  ships dangling relative symlinks under `copyparty/web/a/`
  (`partyfuse.py` -> `../../../bin/partyfuse.py`, `u2c.py`,
  `webdav-cfg.txt` -> `../../../contrib/webdav-cfg.bat`) whose targets
  (`bin/`, `contrib/`) are **not in the sdist**. `--no-dereference`
  compares them as symlinks. (If a symlink genuinely changed between
  versions it will show up in the diff — keep it.)
- The sdist extracts to a versioned top-level dir (`copyparty-$V/`) whose
  `copyparty/` subdir is the python package; the patch paths are relative
  to the sdist root (`-p1` strips the `a/`/`b/` component).
- The `diff` header lines are cosmetic: regenerated patches carry
  timestamps and the `--no-dereference` flag in the `diff -ruN ...` lines;
  `patch` ignores them. (Verified: regenerating the 1.20.20 patch this way
  reproduces it byte-identically apart from those headers.)
- `python3` is not on PATH here by default; use a Nix-store interpreter if
  you need one (`nix shell nixpkgs#python3`).
- `partftpy` (`partftpy.nix` + `partftpy-pin.json`) is patched the same
  way; it changes far less often.

## Testing the plugin JS

The plugin is vanilla JS with no dependencies; verify it with jsdom:

```sh
# plain `nodejs` bundles npm (there is no separate `nodejs-npm` pkg anymore)
nix shell nixpkgs#nodejs -c sh -c '
  mkdir -p /tmp/vt && cd /tmp/vt
  npm init -y >/dev/null && npm install jsdom --no-audit --no-fund
  cat > test.js <<\'EOF\'
  ... // jsdom harness: build #files rows (with MPlayer (🎧) links in the
      // first <td>), stub window.fetch for ?th=json, eval the plugin,
      // assert: button replaces (🎧), modal opens, selects exist,
      // ?th=mp4:0 source, warming fires for other tracks (Range-limited),
      // track switch updates src, 415 falls back to direct playback
  EOF
  node test.js'
```

jsdom prints harmless `Not implemented: HTMLMediaElement's load()/play()`
warnings. A harness covering the current behavior (row scanning, modal,
selects, warming, saveData, 415 fallback, switching) last ran
**28 passed, 0 failed** on 2026-08-26.

## Operational notes

- Conversion cache: `<histpath>/vr/<rd>/<fn>.<mtime>.mp4` — persistent
  (`/persist/opt/skylake-storage/Services/copyparty-*-hist`, owned
  `copyparty:copyparty`, mode 0700 — not listable as `misi`).
- First conversion of a 1080p/24-min episode: ~76–90 s; the nginx vhost
  must keep `proxy_read_timeout 3600s` (nginx's 60 s default kills the
  request mid-conversion → phones see "Can't play media (invalid MIME
  type)" on the HTML 504 page, and the retry "works" because the
  conversion finished in the background).
- The plugin fires 8KB range-requests for the other audio tracks when the
  modal opens to warm the conversion cache in the background (aborted
  after 15 s; the server keeps converting).
