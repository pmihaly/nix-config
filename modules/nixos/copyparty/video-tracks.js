/* copyparty "video-tracks" browser plugin
 *
 * Adds in-browser video playback with audio/subtitle track selection to
 * copyparty's file browser. Injected via --js-browser /plug/video-tracks.js
 * (served from a read-only [/plug] volume; see the NixOS module).
 *
 * On each video file row it REPLACES the play link that copyparty's built-in
 * MPlayer injects into the first cell (the (🎧) link). That built-in player
 * streams the raw container into a <video> element, which browsers cannot
 * decode for mkv/h265 (MIME/format errors) and which has no track selection.
 * Our ▶ button is now the only play button on video rows.
 *
 * Server protocol (requires the patched copyparty build, ?th= endpoints):
 *   <file>?th=json    200 application/json  {"v":[...],"a":[...],"s":[...],"d":..,"f":..}
 *   <file>?th=mp4[:K] 200 video/mp4         remux/transcode, audio track K (0-based)
 *   <file>?th=vtt:K   200 text/vtt          subtitle track K as webvtt
 *   any failure       415 (Pebkac)
 * An unpatched server answers ?th=json with a JPEG (200 image/jpeg); the
 * plugin detects that via the content-type and falls back to direct
 * playback.
 *
 * Mobile: the player modal stacks the track selects full-width (native
 * <select> pickers), the video gets playsinline, and if the browser refuses
 * autoplay (always true for first plays on phones) a big tap-to-play
 * overlay appears instead of a dead video.
 *
 * Security:
 *  - self-contained vanilla JS (no CDN, CSP-safe: loaded with the page
 *    nonce, no eval, styles injected via a <style> element)
 *  - every server-provided string (track titles, languages, codecs) is
 *    rendered via textContent/labels only — never innerHTML
 *  - file hrefs come from the server-rendered DOM (already percent-quoted)
 *    and are only ever extended with ?th=/&th= query parameters
 */
(function () {
  "use strict";
  if (window.__copypartyVideoTracks) return;
  window.__copypartyVideoTracks = true;

  var VID_EXT = {
    mp4: 1, m4v: 1, mkv: 1, webm: 1, mov: 1, avi: 1, wmv: 1,
    mpg: 1, mpeg: 1, m2ts: 1, ts: 1, "3gp": 1, "3g2": 1, ogv: 1,
    vob: 1, flv: 1, asf: 1, divx: 1,
  };

  function qsa(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function extOf(name) {
    var i = name.lastIndexOf(".");
    if (i < 0 || i === name.length - 1) return "";
    return name.slice(i + 1).toLowerCase();
  }

  function sepOf(href) {
    return href.indexOf("?") >= 0 ? "&" : "?";
  }

  /* ---------- styles (inline <style>: the default copyparty CSP has no
   * style-src restriction) ---------- */
  var css =
    ".vt-play{background:none;border:0;color:#7fa8c9;cursor:pointer;font-size:.9em;padding:2px 4px;line-height:1;-webkit-tap-highlight-color:transparent;user-select:none}" +
    ".vt-play:hover{color:#fff}" +
    ".vt-modal{position:fixed;inset:0;background:rgba(0,0,0,.92);z-index:100000;display:flex;overflow:auto}" +
    ".vt-col{display:flex;flex-direction:column;align-items:center;margin:auto;padding:16px 0}" +
    ".vt-vid{position:relative;width:min(92vw,1280px)}" +
    ".vt-vid video{width:100%;max-height:72vh;background:#000;display:block}" +
    ".vt-big{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.4);border:0;color:#cde;font-size:72px;cursor:pointer;-webkit-tap-highlight-color:transparent}" +
    ".vt-bar{display:flex;gap:10px;align-items:center;margin-top:10px;flex-wrap:wrap;max-width:min(92vw,1280px)}" +
    ".vt-bar label{color:#9ab;font-size:.85em}" +
    ".vt-bar select{background:#101820;color:#cde;border:1px solid #3a4a5a;border-radius:4px;padding:2px 6px;font-size:.9em;min-width:180px;max-width:45vw}" +
    ".vt-msg{color:#fa8;font-family:ui-monospace,monospace;font-size:.85em;margin-top:10px;max-width:85vw;white-space:pre-wrap;text-align:center}" +
    ".vt-close{position:absolute;top:10px;right:14px;background:none;border:0;color:#9ab;font-size:1.6em;cursor:pointer;line-height:1;padding:6px}" +
    ".vt-close:hover{color:#fff}" +
    ".vt-title{position:absolute;top:16px;left:16px;color:#789;font-size:.85em;font-family:ui-monospace,monospace;max-width:50vw;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}" +
    "@media (max-width:700px){" +
    ".vt-vid{width:100vw}" +
    ".vt-vid video{max-height:48vh}" +
    ".vt-bar{width:100vw;max-width:none;flex-direction:column;align-items:stretch;gap:8px;margin-top:8px}" +
    ".vt-bar select{width:100%;max-width:none;min-width:0;font-size:16px;padding:12px}" +
    ".vt-play{font-size:1.5em;padding:8px}" +
    ".vt-title{max-width:56vw;left:12px;top:12px;font-size:.75em}" +
    ".vt-close{font-size:2em;top:2px;right:6px}" +
    "}";
  var styleEl = document.createElement("style");
  styleEl.textContent = css;
  document.head.appendChild(styleEl);

  /* ---------- row scanning: put our ▶ where MPlayer's (🎧) used to be ---------- */
  function makeBtn(href, name) {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "vt-play";
    btn.textContent = "\u25B6";
    btn.title = "play (audio/subtitle track selection)";
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      openPlayer(href, name);
    });
    return btn;
  }

  function scanRows() {
    var rows = qsa("#files tbody tr");
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      var btn = row.__vtBtn;
      if (btn && btn.isConnected) {
        // MPlayer may (re-)inject its (🎧) link into the first cell after we
        // ran; if that happens alongside a still-attached button of ours,
        // move ours into its place so there is only one play button.
        var stray = row.querySelector("td a.play[href^='#']");
        if (stray && btn.parentNode !== stray.parentNode) {
          stray.parentNode.replaceChild(btn, stray);
        }
        continue;
      }
      if (row.__vtDone) continue; // known non-video row
      // LAST <a> in the row is the filename link: MPlayer puts its (🎧)
      // play link in the FIRST cell, and querySelector("td a") would pick
      // that up (href="#a<tid>", textContent="(🎧)") and fail the extension
      // check — so no button would ever appear on exactly the rows we want.
      var links = qsa("td a", row);
      if (!links.length) continue;
      var a = links[links.length - 1];
      var href = a.getAttribute("href") || "";
      if (!href || href.slice(-1) === "/" || href.indexOf("://") === 0) {
        row.__vtDone = true;
        continue;
      }
      var name = a.textContent || "";
      if (!VID_EXT[extOf(name)]) {
        row.__vtDone = true;
        continue;
      }
      btn = makeBtn(href, name);
      row.__vtBtn = btn;
      // Replace MPlayer's built-in play link in the first cell. It streams
      // the raw container (undecodable in browsers for mkv/h265, no track
      // selection); ours is the only play button on this row now.
      var mp = row.querySelector("td a.play[href^='#']");
      if (mp) mp.parentNode.replaceChild(btn, mp);
      else a.parentNode.insertBefore(btn, a);
    }
  }

  /* ---------- track label from a json track object (textContent only) ---------- */
  function labelOf(t, i) {
    var parts = [String(i + 1)];
    if (t.l) parts.push(t.l);
    if (t.t) parts.push(t.t);
    if (t.c) parts.push("(" + t.c + ")");
    return parts.join(" ");
  }
  /* ---------- server-conversion status hint ----------
   * Mirrors the server's codec decision (th_srv.py conv_vrc): the output
   * is a pure remux only when the video codec is in VCOPY and the
   * selected audio codec is in ACOPY; otherwise ffmpeg re-encodes the
   * missing part, which takes a while for large files (e.g. a Japanese
   * FLAC track -> AAC is a one-time ~minute for a 3GB episode). The
   * result is cached server-side, so the wait only happens once per
   * (file, audio track). Without this hint the video just sits at 0%
   * and users give up mid-conversion.
   */
  var VCOPY = { h264: 1, hevc: 1, mpeg4: 1, av1: 1 };
  var ACOPY = { aac: 1, mp3: 1, ac3: 1, eac3: 1, alac: 1 };

  function convHint(doc, aIdx) {
    var v = doc.v && doc.v[0];
    var a = aIdx >= 0 && doc.a ? doc.a[aIdx] : null;
    var vc = v ? String(v.c || "").toLowerCase() : "";
    var ac = a ? String(a.c || "").toLowerCase() : "";
    var vOk = !!VCOPY[vc];
    var aOk = !a || !!ACOPY[ac];
    if (vOk && aOk)
      return "starting\u2026 (first play prepares the file on the server; it is cached afterwards)";
    if (!vOk && !aOk)
      return "transcoding on the server: " + (vc || "?") + "\u2192h264, " + (ac || "?") + "\u2192aac \u2014 can take several minutes; happens once, then cached";
    if (!aOk)
      return "converting audio on the server: " + (ac || "?") + "\u2192aac \u2014 first play may take up to a minute for large files; happens once, then cached";
    return "transcoding video on the server: " + (vc || "?") + "\u2192h264 \u2014 can take several minutes; happens once, then cached";
  }

  /* ---------- the player ---------- */
  var modal = null;

  function onKey(e) {
    if (e.key === "Escape") closeModal();
  }

  function closeModal() {
    if (modal) {
      var v = modal.querySelector("video");
      if (v) v.pause();
      modal.remove();
      modal = null;
    }
    document.removeEventListener("keydown", onKey);
  }

  function tryPlay(v, big) {
    var p = null;
    try {
      p = v.play();
    } catch (_) {
      /* non-promise play() (very old engines) */
    }
    if (p && p.catch)
      p.catch(function () {
        /* autoplay refused (first plays on phones, etc.) — tap-to-play */
        if (big) big.style.display = "flex";
      });
  }

  function openPlayer(href, name) {
    closeModal();

    modal = document.createElement("div");
    modal.className = "vt-modal";
    modal.addEventListener("click", function (e) {
      if (e.target === modal) closeModal();
    });

    var title = document.createElement("div");
    title.className = "vt-title";
    title.textContent = name;
    modal.appendChild(title);

    var close = document.createElement("button");
    close.type = "button";
    close.className = "vt-close";
    close.textContent = "\u2715";
    close.addEventListener("click", function (e) {
      e.stopPropagation();
      closeModal();
    });
    modal.appendChild(close);

    var col = document.createElement("div");
    col.className = "vt-col";
    modal.appendChild(col);

    var vidWrap = document.createElement("div");
    vidWrap.className = "vt-vid";

    var video = document.createElement("video");
    video.controls = true;
    video.preload = "auto";
    video.playsInline = true;
    video.setAttribute("playsinline", "");
    video.setAttribute("webkit-playsinline", "");
    video.setAttribute("x5-playsinline", "");
    vidWrap.appendChild(video);

    // big tap-to-play overlay (mobile autoplay fallback)
    var big = document.createElement("button");
    big.type = "button";
    big.className = "vt-big";
    big.textContent = "\u25B6";
    big.style.display = "none";
    big.addEventListener("click", function (e) {
      e.stopPropagation();
      big.style.display = "none";
      tryPlay(video, big);
    });
    vidWrap.appendChild(big);

    video.addEventListener("play", function () {
      big.style.display = "none";
    });

    // the conversion hint is cleared as soon as real playback starts
    video.addEventListener("playing", function () {
      big.style.display = "none";
      msg.textContent = "";
    });

    video.addEventListener("waiting", function () {
      if (!msg.textContent) msg.textContent = "buffering\u2026";
    });

    video.addEventListener("error", function () {
      if (video.error)
        msg.textContent = "playback error (media error code " + video.error.code + ") \u2014 this file may not be decodable in this browser";
    });

    col.appendChild(vidWrap);

    var bar = document.createElement("div");
    bar.className = "vt-bar";
    col.appendChild(bar);

    var msg = document.createElement("div");
    msg.className = "vt-msg";
    col.appendChild(msg);

    document.body.appendChild(modal);
    document.addEventListener("keydown", onKey);

    var sep = sepOf(href);
    var audios = [];
    var subs = [];
    var aIdx = 0;
    var sIdx = -1;
    var started = false;

    function applyTracks() {
      var oldTracks = qsa("track", video);
      for (var i = 0; i < oldTracks.length; i++) video.removeChild(oldTracks[i]);
      var pos = video.currentTime || 0;
      var url = href + sep + "th=mp4" + (audios.length ? ":" + aIdx : "");
      if (sIdx >= 0 && subs[sIdx]) {
        var tr = document.createElement("track");
        tr.kind = "subtitles";
        tr.label = labelOf(subs[sIdx], sIdx);
        tr.default = true;
        tr.src = href + sep + "th=vtt:" + sIdx;
        video.appendChild(tr);
      }
      video.src = url;
      if (pos > 0) {
        video.addEventListener(
          "loadedmetadata",
          function () {
            video.currentTime = pos;
          },
          { once: true }
        );
      }
      video.load();
      tryPlay(video, big);
    }

    function directPlay(text) {
      msg.textContent = text;
      video.src = href;
      video.load();
      started = true;
      tryPlay(video, big);
    }

    function setupTracks(doc) {
      audios = doc.a || [];
      subs = doc.s || [];
      if (!doc.v && !audios.length) {
        directPlay("no playable streams; opening file directly");
        return;
      }
      var aSel = null;
      if (audios.length) {
        aSel = document.createElement("select");
        aSel.setAttribute("aria-label", "audio track");
        var aLab = document.createElement("label");
        aLab.textContent = "audio";
        bar.appendChild(aLab);
        bar.appendChild(aSel);
        audios.forEach(function (t, i) {
          var o = document.createElement("option");
          o.value = String(i);
          o.textContent = labelOf(t, i);
          aSel.appendChild(o);
        });
        aSel.addEventListener("change", function () {
          aIdx = parseInt(aSel.value, 10) || 0;
          msg.textContent = convHint(doc, aIdx);
          if (started) applyTracks();
        });
      }
      var sSel = null;
      if (subs.length) {
        sSel = document.createElement("select");
        sSel.setAttribute("aria-label", "subtitle track");
        var sLab = document.createElement("label");
        sLab.textContent = "subtitles";
        bar.appendChild(sLab);
        bar.appendChild(sSel);
        var oOff = document.createElement("option");
        oOff.value = "-1";
        oOff.textContent = "off";
        sSel.appendChild(oOff);
        subs.forEach(function (t, i) {
          var o = document.createElement("option");
          o.value = String(i);
          o.textContent = labelOf(t, i);
          sSel.appendChild(o);
        });
        sSel.addEventListener("change", function () {
          sIdx = parseInt(sSel.value, 10);
          if (sIdx < 0) sIdx = -1;
          if (started) applyTracks();
        });
        sIdx = -1;
      }
      msg.textContent = convHint(doc, 0);
      aIdx = 0;
      applyTracks();
      started = true;
      if (aSel) aSel.value = "0";
      if (sSel) sSel.value = "-1";
    }

    msg.textContent = "loading metadata\u2026";
    fetch(href + sep + "th=json", { credentials: "same-origin" })
      .then(function (res) {
        if (res.status === 415) {
          directPlay("server cannot convert this file; trying direct playback");
          return null;
        }
        if (!res.ok) {
          directPlay("metadata request failed (HTTP " + res.status + ")");
          return null;
        }
        var ct = res.headers.get("content-type") || "";
        if (ct.indexOf("application/json") < 0) {
          /* unpatched server: ?th=json came back as a jpeg thumbnail */
          directPlay("conversion not available on this server; trying direct playback");
          return null;
        }
        return res.json();
      })
      .then(function (doc) {
        if (doc) setupTracks(doc);
      })
      .catch(function () {
        if (!started) directPlay("metadata request failed (network error); trying direct playback");
      });
  }

  /* ---------- init: initial scan + observer for in-place re-renders ---------- */
  try {
    var mo = new MutationObserver(function () {
      clearTimeout(mo._t);
      mo._t = setTimeout(scanRows, 200);
    });
    mo.observe(document.body, { childList: true, subtree: true });
    scanRows();
  } catch (e) {
    try {
      scanRows();
    } catch (_) {
      /* noop */
    }
  }
})();
