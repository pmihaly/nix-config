/* copyparty "video-tracks" browser plugin
 *
 * Adds in-browser video playback with audio/subtitle track selection to
 * copyparty's file browser. Injected via --js-browser /plug/video-tracks.js
 * (served from a read-only [/plug] volume; see the NixOS module).
 *
 * Server protocol (requires the patched copyparty build, ?th= endpoints):
 *   <file>?th=json    200 application/json  {"v":[...],"a":[...],"s":[...],"d":..,"f":..}
 *   <file>?th=mp4[:K] 200 video/mp4         remux/transcode, audio track K (0-based
 *   <file>?th=vtt:K   200 text/vtt          subtitle track K as webvtt
 *   any failure       415 (Pebkac)
 * An unpatched server answers ?th=json with a JPEG (200 image/jpeg); the
 * plugin detects that via the content-type and falls back to direct
 * playback.
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
    mp4: 1, m4v: 1, mkv:1, webm: 1, mov: 1, avi: 1, wmv: 1,
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
    ".vt-play{background:none;border:0;color:#7fa8c9;cursor:pointer;font-size:.85em;padding:0 3px;line-height:1}" +
    ".vt-play:hover{color:#fff}" +
    ".vt-modal{position:fixed;inset:0;background:rgba(0,0,0,.88);z-index:100000;display:flex;flex-direction:column;align-items:center;justify-content:center}" +
    ".vt-modal video{width:min(92vw,1280px);max-height:72vh;background:#000}" +
    ".vt-bar{display:flex;gap:10px;align-items:center;margin-top:10px;flex-wrap:wrap}" +
    ".vt-bar label{color:#9ab;font-size:.85em}" +
    ".vt-bar select{background:#101820;color:#cde;border:1px solid #3a4a5a;border-radius:4px;padding:2px 6px;font-size:.85em}" +
    ".vt-msg{color:#fa8;font-family:ui-monospace,monospace;font-size:.85em;margin-top:10px;max-width:85vw;white-space:pre-wrap;text-align:center}" +
    ".vt-close{position:absolute;top:10px;right:14px;background:none;border:0;color:#9ab;font-size:1.6em;cursor:pointer;line-height:1}" +
    ".vt-close:hover{color:#fff}" +
    ".vt-title{position:absolute;top:14px;left:16px;color:#789;font-size:.85em;font-family:ui-monospace,monospace;max-width:50vw;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}";
  var styleEl = document.createElement("style");
  styleEl.textContent = css;
  document.head.appendChild(styleEl);

  /* ---------- row scanning: add a ▶ button to video file rows ---------- */
  function scanRows() {
    var rows = qsa("#files tbody tr");
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      if (row.__vtDone) continue;
      row.__vtDone = true;
      // LAST <a> in the row is the filename link: copyparty's built-in
      // MPlayer puts a (🎧) play link in the FIRST cell for any
      // audio/video row, and querySelector("td a") would pick that up
      // (href="#a<tid>", textContent="(🎧)") and fail the extension check
      // — so no button would ever appear on exactly the rows we want.
      var links = qsa("td a", row);
      if (!links.length) continue;
      var a = links[links.length - 1];
      var href = a.getAttribute("href") || "";
      if (!href || href.slice(-1) === "/" || href.indexOf("://") === 0) continue;
      var name = a.textContent || "";
      if (!VID_EXT[extOf(name)]) continue;
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "vt-play";
      btn.textContent = "\u25B6";
      btn.title = "play";
      btn.addEventListener("click", function (e) {
        e.preventDefault();
        e.stopPropagation();
        openPlayer(href, name);
      });
      a.parentNode.insertBefore(btn, a);
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

    var video = document.createElement("video");
    video.controls = true;
    video.preload = "auto";
    modal.appendChild(video);

    var bar = document.createElement("div");
    bar.className = "vt-bar";
    modal.appendChild(bar);

    var msg = document.createElement("div");
    msg.className = "vt-msg";
    modal.appendChild(msg);

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
      video.play().catch(function () {
        /* autoplay may be blocked; user hits play */
      });
    }

    function setupTracks(doc) {
      audios = doc.a || [];
      subs = doc.s || [];
      if (!doc.v && !audios.length) {
        msg.textContent = "no playable streams; opening file directly";
        video.src = href;
        video.load();
        started = true;
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
      msg.textContent = "";
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
          msg.textContent = "server cannot convert this file; trying direct playback";
          video.src = href;
          video.load();
          started = true;
          return null;
        }
        if (!res.ok) {
          msg.textContent = "metadata request failed (HTTP " + res.status + ")";
          video.src = href;
          video.load();
          started = true;
          return null;
        }
        var ct = res.headers.get("content-type") || "";
        if (ct.indexOf("application/json") < 0) {
          /* unpatched server: ?th=json came back as a jpeg thumbnail */
          msg.textContent = "conversion not available on this server; trying direct playback";
          video.src = href;
          video.load();
          started = true;
          return null;
        }
        return res.json();
      })
      .then(function (doc) {
        if (doc) setupTracks(doc);
      })
      .catch(function () {
        msg.textContent = "metadata request failed (network error); trying direct playback";
        if (!started) {
          video.src = href;
          video.load();
          started = true;
        }
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
    try { scanRows(); } catch (_) { /* noop */ }
  }
})();
