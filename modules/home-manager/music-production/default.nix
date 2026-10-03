{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.music-production.wine;
  home = config.home.homeDirectory;
  # NOTE: the bottle/standalone side runs wine staging (11.16) so Kontakt's
  # file dialogs work (wine 9.21, wineRelease="yabridge", hard-crashes
  # comdlg32). The BRIDGED side (yabridge in Ardour) deliberately runs 9.21
  # (see use-cases/music-production/default.nix): on 11.x every yabridge-hosted
  # window had a constant vertical cursor offset on niri/XWayland; 9.21 is
  # cursor-correct. The two never share a wine for one prefix boot.
  winePkg = pkgs.wineWow64Packages.staging;
  runnerName = "wine-yabridge-${winePkg.version}";
  bottleName = cfg.bottleName;
  bottlePath = "${home}/.local/share/bottles/bottles/${bottleName}";

  yabridgectl = pkgs.yabridgectl + "/bin/yabridgectl";

  # Re-sync the yabridge shims to EXACTLY one level, NON-destructively.
  # yabridgectl indexes the plugin dirs recursively and re-discovers its own
  # 'yabridge/' output shims (the chainloaders plus the back-symlinks yabridge
  # leaves next to them), nesting one level deeper on EVERY sync (each extra
  # level shows up as one more duplicate plugin in Ardour's plugin list).
  #
  # `sync --prune` alone does not converge either: it deletes leftover .so
  # files and then re-indexes the back-symlinks, so the shims move one level
  # deeper on every run. The fix is to take yabridgectl's own output dirs (and
  # the real-bundle tree of the Ardour VST3 fix) out of its index entirely with
  # its blacklist; `sync` is then idempotent and `--prune` cleans the nesting
  # levels created before.
  #
  # Historical trap (2026-09-24): the old wipe-before-sync approach destroyed
  # EVERY shim whenever the sync failed for any reason -- at login the service's
  # `yabridgectl sync` failed, all shims vanished silently (output + exit code
  # swallowed by `> /dev/null 2>&1 || true`), and Ardour froze instantiating a
  # yabridge plugin (MJUCjr) from a session -- it looked like "Vital freezes
  # Ardour". Nothing is hidden here: any yabridgectl failure aborts (set -e) and
  # lands in the service journal instead of vanishing into `|| true`.
  yabridgeSync = pkgs.writeShellScriptBin "yabridge-sync" ''
    set -eu
    readonly YABRIDGECTL='${yabridgectl}'

    # yabridgectl indexes every configured plugin dir *including its own shim
    # output*, so each plain `sync` treats the previous shims as input and adds
    # another nesting level (yabridge/ -> yabridge/yabridge/ -> ...); Ardour
    # then lists every bridged plugin once per level. Blacklisting the output
    # dirs keeps them out of the index and makes sync idempotent at one level.
    # `blacklist add` canonicalizes and requires the path to exist.
    # ~/.vst3/nix is the real bundle tree of the Ardour VST3 fix: it is not
    # indexed either, but `sync --prune` deletes its .so files as "unrelated"
    # leftovers when it is not blacklisted.
    mkdir -p "$HOME/.vst3/nix"
    for d in "$HOME/.vst3/nix" "$HOME/.vst/yabridge" "$HOME/.vst3/yabridge" "$HOME/.clap/yabridge"; do
      [ -d "$d" ] || continue
      "$YABRIDGECTL" blacklist list | grep -qxF "$d" \
        || "$YABRIDGECTL" blacklist add "$d"
    done

    # drop the nesting levels created before the output dirs were blacklisted,
    # together with their Ardour cache entries (*.v3i/*.v2i are keyed by module
    # path), so a later plugin list cannot resurrect a shim that is gone
    find "$HOME/.vst" "$HOME/.vst3" "$HOME/.clap" \
      -type d -path '*/yabridge/yabridge' -prune -exec rm -rf {} + 2>/dev/null || true
    grep -l -E 'yabridge/yabridge' "$HOME/.cache/ardour9"/vst*/* 2>/dev/null \
      | xargs -r rm -f

    # (re)create/update the shims; --prune drops leftovers from earlier layouts
    "$YABRIDGECTL" sync --prune

    # Ardour blacklists plugins that crashed during scanning, and our shim
    # paths can end up there after a layout change or a mid-sync scan, which
    # makes Ardour 'forget' the VSTs. Drop our entries from every blacklist
    # (Ardour will rescan cleanly).
    for bl in "$HOME/.cache/ardour9"/vst*_x64_blacklist.txt; do
      [ -f "$bl" ] && sed -i "\#$HOME/.vst#d" "$bl" || true
    done
  '';

  # Ardour lists every nix-installed VST3 instrument twice.
  #
  # Ardour's VST3 discovery walks each plugin directory recursively
  # (PBD::find_paths_matching_filter in libs/pbd/file_utils.cc), and it
  # realpath()s every directory it descends into (`PBD::path_expand` ends in
  # `canonical_path` = realpath(3)) -- while the plugin's identity keeps the
  # *unresolved* path: `vst3_discover()` keys the cache file by
  # sha1(module_path) and stores module_path in `info->path`
  # (libs/ardour/plugin_manager.cc, libs/ardour/vst3_scan.cc).
  #
  # Home Manager's lib/vst3/*.vst3 bundles are symlinks into the nix store, so
  # each plugin is discovered twice under two different names:
  #   /etc/profiles/per-user/$USER/lib/vst3/Dexed.vst3/.../Dexed.so
  #   /nix/store/<pkg>/lib/vst3/Dexed.vst3/.../Dexed.so
  # Both are registered => every VST3 instrument appears twice in Ardour's
  # instrument list (LV2 is unaffected: its bundle path is stable).
  # Verified by diffing the Add Track -> MIDI -> Instrument list with symlinked
  # vs. real bundle directories: real bundle dirs => every plugin exactly once.
  #
  # Fix: give Ardour a stable REAL bundle tree per plugin under ~/.vst3 (which is
  # already in Ardour's VST3 search path, both via the built-in default and via
  # the configured path), with only the leaf .so symlinked into the store. The
  # identity is then the ~/.vst3 path in both walks, and the cache entries we
  # generate for it are the only ones that match.
  #
  # Two things make that stick:
  #  * the Ardour cache entries for the symlinked profile bundles are dropped
  #    (immediate), and their module paths are blacklisted (so a later rescan
  #    cannot re-register them -- Ardour checks the blacklist before the cache
  #    lookup and before scanning);
  #  * ensureBottle blacklists ~/.vst3/nix in yabridgectl, otherwise
  #    `yabridgectl sync --prune` deletes the .so files of this tree as
  #    "unrelated" files on its next run.
  vst3RealBundles = pkgs.writeShellScriptBin "ardour-vst3-realbundles" ''
    set -eu

    readonly PROFILE_VST3="/etc/profiles/per-user/$USER/lib/vst3"
    readonly REAL="$HOME/.vst3/nix"
    readonly CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ardour9/vst"
    readonly ARDOUR_LIB='${pkgs.ardour}/lib/ardour9'
    readonly SCANNER="$ARDOUR_LIB/ardour-vst3-scanner"

    # systemd's user-manager PATH is minimal -- don't depend on it.
    PATH='${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin'
    export PATH

    [ -d "$PROFILE_VST3" ] || exit 0

    mkdir -p "$REAL" "$CACHE"

    for b in "$PROFILE_VST3"/*.vst3; do
      [ -e "$b" ] || continue
      name="$(basename "$b")"
      base="''${name%.vst3}"
      module="$(realpath "$b/Contents/x86_64-linux/$base.so" 2>/dev/null || true)"
      [ -n "$module" ] && [ -f "$module" ] || continue

      # real bundle dir, with only the leaf .so symlinked into the store
      mkdir -p "$REAL/$name/Contents/x86_64-linux"
      ln -sfn "$module" "$REAL/$name/Contents/x86_64-linux/$base.so"

      # (re)generate Ardour's cache entry for this bundle
      LD_LIBRARY_PATH="$ARDOUR_LIB" "$SCANNER" -q "$REAL/$name" >/dev/null 2>&1 || true
    done

    # Drop bundles (and their cache entries) for plugins that are gone.
    for b in "$REAL"/*.vst3; do
      [ -e "$b" ] || continue
      name="$(basename "$b")"
      if [ ! -e "$PROFILE_VST3/$name" ]; then
        rm -rf "$b"
      fi
    done

    # Drop Ardour's cache entries for the *symlinked* profile bundles: Ardour
    # would register those in addition to the real ones, i.e. list them twice.
    # Both spellings occur in older caches: the resolved store path and the
    # literal /etc/profiles/... path.
    for f in "$CACHE"/*.v3i; do
      [ -f "$f" ] || continue
      if grep -qE -- '(-home-manager-path|/etc/profiles/per-user/[^/]*)/lib/vst3/' "$f"; then
        rm -f "$f"
      fi
    done

    # ...and keep them out for good. Dropping the cache entries is not enough:
    # a rescan (the user clicking "Discover Plugins", or Ardour deciding its
    # cache is stale) walks the profile path again and re-creates them. Ardour
    # checks its VST3 blacklist *before* the cache lookup and before scanning,
    # so blacklisting the profile bundles' module paths makes them ignored even
    # by a full rescan, leaving the real bundles above as the only source.
    # Entries are keyed by module path and the profile store path changes on
    # every rebuild, so ours are dropped and re-added on each run.
    readonly ABL="$(dirname "$CACHE")/vst3_x64_blacklist.txt"
    readonly PDIR="$(realpath "$PROFILE_VST3")"
    if [ -f "$ABL" ]; then
      sed -i -e '\#-home-manager-path/lib/vst3/#d' -e '\#/etc/profiles/per-user/[^/]*/lib/vst3/#d' "$ABL"
    fi
    for b in "$PROFILE_VST3"/*.vst3; do
      [ -e "$b" ] || continue
      name="$(basename "$b")"
      base="''${name%.vst3}"
      # the literal path, and the canonical profile dir Ardour's walk uses
      printf '%s\n' "$b/Contents/x86_64-linux/$base.so"
      printf '%s\n' "$PDIR/$name/Contents/x86_64-linux/$base.so"
    done >> "$ABL"
  '';

  # Idempotently create/refresh the Bottles bottle that holds our Windows VST
  # installs, then mirror the Windows plugins installed in it into the yabridge
  # directories and re-sync the shims. The prefix is created by the exact wine
  # that yabridge uses to run bridged plugins (wineWow64Packages.yabridge), so
  # nothing gets migrated or re-activated when a plugin loads. wineboot --init is
  # fully headless.
  ensureBottle = pkgs.writeShellScriptBin "vst-bottle-ensure" ''
        set -eu
        readonly BOTTLE='${bottlePath}'
        readonly RUNNERS="$HOME/.local/share/bottles/runners"
        readonly RUNNER="$RUNNERS/${runnerName}"
        readonly WINE='${winePkg}'
        readonly YABRIDGECTL='${yabridgectl}'

        mkdir -p "$BOTTLE" "$RUNNERS" "$HOME/.vst" "$HOME/.vst3" "$HOME/.local/share/yabridge"
        # expose the nix wine to the Bottles GUI as a normal runner
        ln -sfn "$WINE" "$RUNNER"
        # stable yabridge-host.exe location (runtime fallback; silences yabridgectl's warning)
        ln -sfn '${pkgs.yabridge}/bin/yabridge-host.exe' "$HOME/.local/share/yabridge/"

        if [ ! -f "$BOTTLE/drive_c/system.reg" ]; then
          WINEPREFIX="$BOTTLE" "$WINE/bin/wineboot" --init
          WINEPREFIX="$BOTTLE" "$WINE/bin/wineserver" -k
        fi

        cat > "$BOTTLE/bottle.yml" <<EOF
    Name: ${bottleName}
    Creation Date: $(date '+%Y-%m-%d %H:%M:%S')
    Runner: ${runnerName}
    Arch: amd64
    EOF
        cat > "$BOTTLE/prefix.yml" <<EOF
    Arch: amd64
    WinePrefix: $BOTTLE
    WineVersion: ${runnerName}
    EOF

        # copy 64-bit Windows VSTs installed in the bottle into the yabridge dirs
        # (NI-style installers use 'VSTPlugins 64 bit'; keep only 64-bit plugins,
        # yabridge 5.x dropped 32-bit support)
        find "$BOTTLE/drive_c/Program Files" -maxdepth 4 -type d \
          \( -iname "VSTPlugins 64 bit" -o -iname "VST2Plugins*" -o -iname "VSTPlugins" \) 2>/dev/null \
          | while read -r d; do
              case "$d" in *"32 bit"*) continue;; esac
              [ -d "$d" ] || continue
              find "$d" -maxdepth 1 -type f -iname '*.dll' -print0 2>/dev/null \
                | while IFS= read -r -d ''' f; do cp -u "$f" "$HOME/.vst/"; done
            done
        # SoundToys-style bundles keep their dlls in an x64/ subfolder inside the
        # VSTPlugins dir (VSTPlugins/SoundToys/x64); the flat loop above misses them.
        find "$BOTTLE/drive_c/Program Files" -maxdepth 5 -type d -ipath "*VSTPlugins*/x64" 2>/dev/null \
          | while read -r d; do
              [ -d "$d" ] || continue
              find "$d" -maxdepth 1 -type f -iname '*.dll' -print0 2>/dev/null \
                | while IFS= read -r -d ''' f; do cp -u "$f" "$HOME/.vst/"; done
            done
        # VST3 plugins (folder-based .vst3 or single-file .vst3, e.g. Kontakt 8)
        find "$BOTTLE/drive_c/Program Files/Common Files" -maxdepth 2 -type d -iname "VST3" 2>/dev/null \
          | while read -r d; do
              [ -d "$d" ] || continue
              find "$d" -maxdepth 3 \( -type d -o -type f \) -iname '*.vst3' -print0 2>/dev/null \
                | while IFS= read -r -d ''' f; do [ -e "$f" ] && cp -ru "$f" "$HOME/.vst3/"; done
            done

        # make sure the yabridge dirs are registered (the shared wrapper also
        # blacklists its own output dirs and $HOME/.vst3/nix before syncing).
        for dir in "$HOME/.vst" "$HOME/.vst3"; do
          "$YABRIDGECTL" add "$dir"
        done
        # NOTE: use the explicit /bin path here — lib.getExe (and bare
        # stringified derivations) render the derivation ROOT inside a shell
        # string, not the executable; only desktop/systemd attrs append /bin.
        '${yabridgeSync}/bin/yabridge-sync'
  '';

  # Ardour with the VST bottle as WINEPREFIX (yabridge reads it to locate/run
  # Windows plugins). Native Ardour is unaffected by the variable.
  ardourVst = pkgs.writeShellScriptBin "ardour-vst" ''
    export WINEPREFIX='${bottlePath}'
    exec '${pkgs.ardour}/bin/ardour9' "$@"
  '';

  # Run any Windows executable (.exe installer, etc.) inside the VST bottle.
  vstRun = pkgs.writeShellScriptBin "vst-run" ''
    export WINEPREFIX='${bottlePath}'
    exec '${winePkg}/bin/wine' "$@"
  '';

  # Open Kontakt instrument files directly. The internal Load browser needs the
  # NI platform framework (Common Files/Native Instruments/NTK/ni-platform.dll
  # + resources_ENG) that the bobdule repack does NOT ship, so the Load button
  # silently no-ops without it (and XWayland drag&drop is another dead end).
  # Kontakt accepts the patch as a plain argv argument, which works reliably:
  #   Kontakt 8.exe "Z:\path\to\Wotan_Basses.nki"
  kontaktExe = "C:\\Program Files\\Native Instruments\\Kontakt 8\\Kontakt 8.exe";
  kontaktOpen = pkgs.writeShellScriptBin "kontakt-open" ''
    set -eu
    [ "$#" -ge 1 ] || { echo "usage: kontakt-open <file.nki|.nkm> ..." >&2; exit 1; }
    export WINEPREFIX='${bottlePath}'
    local -a wargs=()
    for f in "$@"; do
      # Unix /home/... -> Z:\home\... (paths with spaces stay intact)
      wargs+=("Z:$(printf '%s' "$f" | sed -e 's#^/##' -e 's#/#\\#g')")
    done
    exec '${winePkg}/bin/wine' '${kontaktExe}' "''${wargs[@]}"
  '';

  # Bounce each Digitakt track to its own WAV by muting the other tracks on the
  # machine and recording the USB stereo input via pipewire. The Digitakt is
  # class-compliant stereo only (no Overbridge multitrack) and has NO solo CC --
  # the only per-track control over MIDI is mute (CC 94 on the track's dedicated
  # channel, value 1/0, confirmed by capturing the machine's own transmissions).
  # So a per-track take = mute all OTHER tracks, record, unmute all.
  #
  # IMPORTANT: this cannot strip master FX from the take -- the master
  # compressor (incl. sidechain) and the delay/reverb sends sit on the master
  # bus and land in the USB output. Before bouncing, bypass the compressor on
  # the machine itself (the -y flag skips the reminder).
  #
  # MIDI is sent as raw CC to the ALSA MIDI port (amidi -S) - the transport
  # confirmed against this machine (aplaymidi also works but costs ~2s per
  # message, too slow for 8 tracks). CC semantics per Digitakt User Manual
  # App. B: Track Mute = CC 94 on channel = track number (TRACK 1-8 in
  # SETTINGS>MIDI CONFIG>CHANNELS), value 1 = mute, 0 = unmute. Existing mutes
  # are reset by a bounce.
  digitaktBounce = pkgs.writeShellScriptBin "digitakt-bounce" ''
        set -u

        out="$HOME/Music/digitakt-bounce/$(date +%Y%m%d-%H%M%S)"
        length=16
        countin=3
        tracks="1-8"
        firstch=1
        port=""
        source=""
        mixflag=0
        assume_off=0
        dryrun=0
        verbose=0
        transport=1
        waitsec=0
        bpm=120

        # if the user hits Ctrl+C mid-take, kill the background pw-record too
        _recpid=""
        trap '_rc=$?; [ -n "$_recpid" ] && kill "$_recpid" 2>/dev/null; [ -n "$_clkpid" ] && kill "$_clkpid" 2>/dev/null; exit $((_rc ? _rc : 130))' INT TERM
        rec_launch() {
          timeout -s INT "$length" "$PWRECORD" \
            --target "$source" --format s16 --rate 48000 --channels 2 "$1" &
          _recpid=$!
        }

        usage() {
          cat <<EOF
    Usage: digitakt-bounce [OPTIONS]

    Records each Digitakt track soloed into its own WAV by muting the OTHER tracks
    via MIDI and capturing the USB stereo input with pw-record.

    Options:
      -o DIR        output dir   (default: ~/Music/digitakt-bounce/<timestamp>)
      -l SECONDS    take length  (default: 16; set to your loop/pattern length)
      -t TRACKS     take set, e.g. 1-8, 1,3,5-8 (default: 1-8)
      -c CHANNEL    MIDI channel of track 1 (default: 1; tracks 2-8 follow)
      -s SOURCE     pipewire source (default: auto-detect Digitakt input)
      -m            also record a full-mix take first (no mutes) as 00_mix.wav
      -T            don't send MIDI transport (Stop/clock/Start) per take
      -b BPM        tempo of the paced MIDI clock (default: 120). Set this to your
                    pattern BPM so the Digitakt plays at the right speed and bar-
                    aligned; it follows the sent clock exactly.
      -q            no countdown between takes
      -y            yes, master compressor/FX already bypassed on the machine
      -n            dry run: print what would be done
      -v            verbose: log every MIDI message sent
      -h            show this help

    By default each take is bar-aligned: Stop x2 (FC FC) + All Sound Off (CC120 -
    cuts any loop-mode sample tails, like double-tapping [STOP]), then a
    CONTINUOUS paced MIDI clock F8 stream at -b BPM (default 120) is fed while
    Start (FA) restarts the pattern from the top. A continuous clock is required:
    the Digitakt ignores a bare FA and a short burst makes it sprint through a
    fast version of the loop at the top of the take. Requires SETTINGS > MIDI
    CONFIG > SYNC > CLOCK RECEIVE (and TRANSPORT RECEIVE for the FC/FA). Use
    -w SECONDS if your pattern needs a moment before the downbeat, or -T to press
    play yourself.

    Digitakt MIDI: mute = CC94 on the track's channel, value 1=mute / 0=unmute.
    There is NO solo CC on the Digitakt; channels are TRACK 1-8 in
    SETTINGS > MIDI CONFIG > CHANNELS. Pre-existing mutes are cleared by a bounce.

    Master FX: bypass the master compressor (sidechain) and zero the delay/reverb
    sends on the Digitakt first, or they end up in every take.
    EOF
        }

        die() {
          echo "digitakt-bounce: $*" >&2
          exit 1
        }

        while [ "$#" -gt 0 ]; do
          case "$1" in
            -o) out="$2"; shift 2 ;;
            -l) length="$2"; shift 2 ;;
            -t) tracks="$2"; shift 2 ;;
            -c) firstch="$2"; shift 2 ;;
            -s) source="$2"; shift 2 ;;
            -m) mixflag=1; shift ;;
            -q) countin=0; shift ;;
            -y) assume_off=1; shift ;;
            -T) transport=0; shift ;;
            -b) bpm="$2"; shift 2 ;;
            -w) waitsec="$2"; shift 2 ;;
            -n) dryrun=1; shift ;;
            -v) verbose=1; shift ;;
            -h) usage; exit 0 ;;
            *) die "unknown option: $1 (use -h for help)" ;;
          esac
        done

        PWRECORD=$(command -v pw-record) || true
        PWDUMP=$(command -v pw-dump) || true
        [ -n "$PWRECORD" ] || PWRECORD=/run/current-system/sw/bin/pw-record
        [ -n "$PWDUMP" ] || PWDUMP=/run/current-system/sw/bin/pw-dump
        PWRECORD=$(command -v pw-record) || true
        PWDUMP=$(command -v pw-dump) || true
        AMIDI=$(command -v amidi) || true
        [ -n "$PWRECORD" ] || PWRECORD=/run/current-system/sw/bin/pw-record
        [ -n "$PWDUMP" ] || PWDUMP=/run/current-system/sw/bin/pw-dump
        [ -n "$AMIDI" ] || AMIDI=/run/current-system/sw/bin/amidi
        for b in "$PWRECORD" "$PWDUMP" "$AMIDI"; do
          [ -x "$b" ] || die "missing $b (need pipewire + alsa-utils)"
        done

        # --- auto-detect Digitakt ALSA MIDI port
        if [ -z "$port" ]; then
          port=$("$AMIDI" -l 2>/dev/null | awk '/[Dd]igitakt/{print $2; exit}')
          [ -n "$port" ] || die "no Digitakt MIDI port found; pass -p hw:3,0,0"
        fi

        # --- auto-detect Digitakt pipewire input source
        if [ -z "$source" ]; then
          source=$("$PWDUMP" 2>/dev/null \
            | sed -n 's/.*"node\.name": "\(alsa_input[^"]*[Dd]igitakt[^"]*\)".*/\1/p' \
            | head -1)
          [ -n "$source" ] || die "no Digitakt input source found; pass -s <node.name>"
        fi

        if [ "$dryrun" = 1 ]; then
          echo "midi port: $port"
          echo "source:    $source"
          echo "takes:     $tracks x $length s -> $out"
          [ "$mixflag" = 1 ] && echo "+ full-mix take"
          exit 0
        fi

        [ "$assume_off" = 1 ] || {
          echo "Before bouncing, disable master FX on the Digitakt:"
          echo "  * bypass master compressor (sidechain off)"
          echo "  * zero the delay/reverb sends"
          echo "This script cannot remove them from the USB output."
          read -r -p "Ready? [y/N] " ans || true
          case "$ans" in y|Y) ;; *) die "aborted" ;; esac
        }

        mkdir -p "$out" || die "cannot create $out"

        # --- MIDI: raw amidi to the DT's ALSA port (instant, confirmed working:
        # a CC94 on channel N mutes the track; see Digitakt manual App. B).
        send_cc() { # $1=channel 1-16, $2=CC94 value (1=mute 0=unmute)
          local st=$((0xB0 + $1 - 1))
          "$AMIDI" -p "$port" -S "$(printf '%02X %02X %02X' "$st" 94 "$2")" >/dev/null 2>&1 \
            || die "amidi send failed (ch $1 val $2)"
          [ "$verbose" = 1 ] && echo "  midi: ch $1 CC94=$2"
        }
        channel_of() { echo $((firstch + $1 - 1)); }
        mute_tk()   { send_cc "$(channel_of "$1")" 1; }   # mute track $1
        unmute_tk() { send_cc "$(channel_of "$1")" 0; }   # unmute track $1
        # NOTE: helper loops use distinct var names (tt, uu) so they never clobber
        # the outer per-take loop variable in bash.
        unmute_all() {
          local t2
          for t2 in 1 2 3 4 5 6 7 8; do unmute_tk "$t2"; done
        }
        mute_others() { # $1=track to leave playing
          local t2
          for t2 in 1 2 3 4 5 6 7 8; do
            [ "$t2" -ne "$1" ] && mute_tk "$t2"
          done
        }

        # --- MIDI transport -----------------------------------------------------
        # The Digitakt only starts from MIDI CLOCK: a bare FA does nothing, and a
        # burst of F8s makes it sprint through a fast version of the loop at the
        # top of the take - because it consumes queued pulses at line speed, then
        # free-runs at its own tempo. Correct approach = feed a CONTINUOUS, paced
        # MIDI clock (like a real master device) at -b BPM for the whole take: it
        # starts promptly from the top, stays locked, and there is no fast intro.
        #
        # Stopping needs a DOUBLE Stop: one FC halts the sequencer but loop-mode
        # samples keep sounding (like a single [STOP] press); the second FC cuts
        # them - mirrors the hardware double-tap.
        mstop()  { send_raw "FC"; }
        mstop2() {
          mstop; sleep 0.18; mstop
          [ "$verbose" = 1 ] && echo "  midi: Stop (FC FC)"
        }
        mstart() { send_raw "FA"; [ "$verbose" = 1 ] && echo "  midi: Start (FA)"; }
        # All-Sound-Off (CC120=0) on every track channel: cuts any looping sample,
        # the MIDI equivalent of double-tapping [STOP] on the hardware.
        panic() {
          local st s ch i
          s=""
          i=0
          while [ "$i" -lt 8 ]; do
            st=$((0xB0 + firstch + i - 1))
            s="$s $(printf '%02X' "$st") 78 00"
            i=$((i + 1))
          done
          send_raw "$s"
          [ "$verbose" = 1 ] && echo "  midi: All Sound Off (CC120)"
        }

        _clkpid=""
        clock_on() { # paced 24-F8-per-beat stream @ $bpm, sent in ~0.25s chunks
          local per=$(( (bpm + 5) / 10 ))   # pulses per 0.25s = 0.1 * BPM
          [ "$per" -gt 0 ] || per=12
          local s
          s=$(printf 'F8 %.0s' $(seq 1 "$per"))
          (
            while :; do
              "$AMIDI" -p "$port" -S "$s" >/dev/null 2>&1 || break
              sleep 0.25
            done
          ) &
          _clkpid=$!
        }
        clock_off() {
          [ -n "$_clkpid" ] && kill "$_clkpid" 2>/dev/null
          _clkpid=""
        }

        seq_cut() {   # double-stop + sound-off: silence the room / cut loop tails
          [ "$transport" = 1 ] || return 0
          mstop2
          panic
        }
        seq_go() {    # establish clock, then start from the top
          [ "$transport" = 1 ] || return 0
          clock_on          # paced external clock at -b BPM
          sleep 0.35        # let the Digitakt lock to it
          mstart            # start playback from the top
          [ "$waitsec" -gt 0 ] && sleep "$waitsec"
        }
        seq_stop() {
          [ "$transport" = 1 ] || return 0
          clock_off
          mstop2            # double-stop + sound-off cuts loop-mode tails
          panic
          sleep 0.2
        }

        send_raw() { # $1 = hex bytes; bypasses channel math
          "$AMIDI" -p "$port" -S "$1" >/dev/null 2>&1 \
            || die "amidi send failed: $1"
        }

        take() { # $1 label, $2 file
          echo "  $1: $2"
          # 1) cut any looping tail (room silence)  2) start recorder so its
          # stream is open in time  3) feed clock + Start so the DT begins playing
          # exactly as capture kicks in - no stray audio at the head of the take.
          seq_cut
          rec_launch "$2"
          local recpid=$_recpid
          sleep 0.3
          seq_go
          wait "$recpid"
          local rc=$?
          _recpid=""
          [ "$rc" = 0 ] || [ "$rc" = 124 ] || die "pw-record failed on take $1"
          sz=$(stat -c%s "$2" 2>/dev/null || echo 0)
          [ "$sz" -gt 1000 ] || die "take $1 is empty ($sz bytes) - is the Digitakt playing?"
        }

        countdown() {
          [ "$countin" -gt 0 ] || return 0
          i=$countin
          while [ "$i" -gt 0 ]; do
            printf '\a'
            echo "  ...$i s" >&2
            sleep 1
            i=$((i - 1))
          done
        }

        expand_tracks() { # echo expanded track numbers
          local list t a b i
          list=$(echo "$tracks" | tr ',' ' ')
          for t in $list; do
            case "$t" in
              *-*)
                a=$(echo "$t" | cut -d- -f1)
                b=$(echo "$t" | cut -d- -f2)
                i=$a
                while [ "$i" -le "$b" ]; do echo "$i"; i=$((i + 1)); done
                ;;
              *) echo "$t" ;;
            esac
          done
        }

        echo "---"
        echo "midi port: $port"
        echo "source:    $source"
        echo "out:       $out"
        echo

        # clean slate + leave everything unmuted at the end
        unmute_all; sleep 0.4

        if [ "$mixflag" = 1 ]; then
          echo "=== full mix (no mutes)"
          countdown
          take "full mix" "$out/00_mix.wav"
        fi

        for t in $(expand_tracks); do
          echo "=== track $t (others muted)"
          mute_others "$t"
          unmute_tk "$t"
          sleep 0.4
          countdown
          take "track $t" "$(printf '%s/track_%02d.wav' "$out" "$t")"
          seq_stop
        done

        unmute_all
        seq_stop
        echo "---"; echo "done -> $out (all tracks unmuted)"
  '';

in
{
  options.modules.music-production.wine = {
    enable = mkEnableOption "declarative wine bottle for Windows VSTs (used via yabridge)";
    bottleName = mkOption {
      type = types.str;
      default = "VST";
      description = "Name of the Bottles bottle holding your Windows VST installs";
    };
  };

  config = mkIf cfg.enable {

    home.packages = [
      ensureBottle
      yabridgeSync
      ardourVst
      vstRun
      kontaktOpen
      pkgs.alsa-utils
      digitaktBounce
    ];

    # .nki/.nkm -> kontakt-open (double-click any instrument in a file manager).
    # Note: no xdg.mimeApps.defaultApplications here on purpose -- it would make
    # Home Manager take over ~/.config/mimeapps.list, which holds the user's
    # hand-made magnet->transmission association. The desktop entry + mime type
    # below are enough for file managers to offer/remember "Open with Kontakt";
    # `xdg-mime default kontakt.desktop audio/x-kontakt-instrument` can be run
    # once if the user wants the default set without HM owning the file.
    xdg.dataFile."mime/packages/kontakt-nki.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <mime-type xmlns="http://www.freedesktop.org/standards/shared-mime-info/1.9"
        type="audio/x-kontakt-instrument">
        <comment>Kontakt instrument</comment>
        <sub-class-of type="audio/x-aiff"/>
        <glob pattern="*.nki"/>
        <glob pattern="*.nkm"/>
        <glob pattern="*.nka"/>
      </mime-type>
    '';
    xdg.desktopEntries.kontakt = {
      name = "Kontakt - open instrument";
      comment = "Open a Kontakt instrument (.nki) in the VST bottle (bypasses the inert Load browser)";
      exec = "${getExe kontaktOpen} %f";
      terminal = false;
      mimeType = [
        "audio/x-kontakt-instrument"
        "application/x-kontakt-nki"
      ];
      categories = [
        "AudioVideo"
        "Audio"
      ];
      settings.StartupWMClass = "Kontakt";
    };

    # Keep the bottle present and consistent at login (create on fresh
    # machines, re-link the runner symlink after store GC on this one).
    systemd.user.services."vst-bottle" = {
      Unit = {
        Description = "Ensure declarative VST wine bottle (yabridge)";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [
          "WINEDEBUG=-all"
          "XDG_CONFIG_HOME=%h/.config"
        ];
        ExecStart = getExe ensureBottle;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Keep Ardour's VST3 plugin list free of nix-profile duplicates; see
    # vst3RealBundles above. Runs after the bottle/yabridge sync so the shim
    # layout it inspects is already converged.
    systemd.user.services."ardour-vst3-realbundles" = {
      Unit = {
        Description = "Materialise real VST3 bundles for Ardour (no profile-path duplicates)";
        After = [
          "graphical-session.target"
          "vst-bottle.service"
        ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe vst3RealBundles;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Replace the stock Ardour desktop entry with one that launches with the
    # VST bottle's WINEPREFIX. Key = "ardour9" shadows the package's
    # ardour9.desktop (xdg.desktopEntries installs with hiPrio) and keeps the
    # original icon/mime/categories + StartupWMClass.
    xdg.desktopEntries.ardour9 = {
      name = "Ardour";
      comment = "Ardour Digital Audio Workstation (Windows VSTs via yabridge)";
      exec = getExe ardourVst;
      icon = "ardour9";
      terminal = false;
      mimeType = [ "application/x-ardour" ];
      categories = [
        "AudioVideo"
        "Audio"
        "X-Recorders"
        "X-Multitrack"
        "X-Jack"
      ];
      settings = {
        StartupWMClass = "Ardour";
        X-NSM-Capable = "true";
        X-NSM-Exec = getExe ardourVst;
      };
    };

    modules.persistence.directories = [
      ".local/share/bottles/runners"
      ".local/share/yabridge"
    ];
  };
}
