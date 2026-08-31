"""Matrix bot for the vision analysis pipeline.

Listens on a Matrix homeserver for ``m.image`` messages, downloads each image,
runs it through :mod:`image_analysis`, and replies in the same room with the
model's description. Configuration is entirely environment-driven so the
deployment NixOS module (and the dev shell) can supply secrets without any
code changes.

Configuration (environment variables)
-------------------------------------
    MATRIX_HOMESERVER        -- e.g. https://matrix.example.org  (required)
    MATRIX_USER_ID           -- full bot id, e.g. @bot:example.org (required)
    MATRIX_ACCESS_TOKEN      -- bot access token (required)
    MATRIX_DEVICE_ID         -- optional device id (else a fresh one each run)
    MATRIX_ALLOWED_USERS     -- comma-separated user ids allowed to trigger
                                analysis; unset/empty = any user in any room
    MATRIX_MAX_IMAGE_RATE    -- max images analysed per room per minute
                                (default ``6``)
    MATRIX_MAX_CONCURRENT    -- max simultaneous vision API calls bot-wide
                                (default ``2``)
    MATRIX_ANALYSIS_PROMPT   -- prompt override passed to image_analysis

Vision credentials honour the same env vars as :mod:`image_analysis`:
``OPENROUTER_API_KEY``/``OPENAI_API_KEY`` etc.

E2EE note
---------
``matrix-nio`` as pinned in the flake has no libolm, so this bot can only read
plaintext rooms — the same capability gap as the main hermes Matrix adapter.
The bot detects ``m.room.encrypted`` state and replies with a single notice so
the operator knows to use an unencrypted room.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set

import nio

from image_analysis import (
    ApiKeyMissingError,
    CorruptImageError,
    ImageAnalysisError,
    UnsupportedImageError,
    VisionAPIError,
    analyze_image,
)

log = logging.getLogger("matrix_vison_bot")

_ENCRYPTION_NOTICE_SENT: Set[str] = set()  # room_id -> we warned already


# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class BotConfig:
    homeserver: str
    user_id: str
    access_token: str
    device_id: Optional[str]
    allowed_users: Optional[Set[str]]
    max_image_rate: int
    max_concurrent: int
    prompt: Optional[str]

    @classmethod
    def from_env(cls, env: Optional[Dict[str, str]] = None) -> "BotConfig":
        env = os.environ if env is None else env

        def required(name: str) -> str:
            val = env.get(name, "").strip()
            if not val:
                raise RuntimeError(
                    f"{name} is required (set it in the environment before "
                    f"starting the bot)"
                )
            return val

        allowed_raw = env.get("MATRIX_ALLOWED_USERS", "").strip()
        allowed: Optional[Set[str]] = None
        if allowed_raw:
            allowed = {u.strip() for u in allowed_raw.split(",") if u.strip()}

        try:
            max_rate = int(env.get("MATRIX_MAX_IMAGE_RATE", "6"))
        except ValueError:
            max_rate = 6
        try:
            max_conc = int(env.get("MATRIX_MAX_CONCURRENT", "2"))
        except ValueError:
            max_conc = 2

        return cls(
            homeserver=required("MATRIX_HOMESERVER"),
            user_id=required("MATRIX_USER_ID"),
            access_token=required("MATRIX_ACCESS_TOKEN"),
            device_id=env.get("MATRIX_DEVICE_ID") or None,
            allowed_users=allowed,
            max_image_rate=max(1, max_rate),
            max_concurrent=max(1, max_conc),
            prompt=env.get("MATRIX_ANALYSIS_PROMPT") or None,
        )


# --------------------------------------------------------------------------- #
# Rate limiting (token bucket, per-room)
# --------------------------------------------------------------------------- #


class RateLimiter:
    """Sliding-window token bucket, keyed per room.

    Allows ``capacity`` tokens per ``window_seconds`` per room, but a single
    burst can always spend ``burst`` tokens so a burst of a few images still
    gets through (then the room cools down).
    """

    def __init__(self, capacity: int, window_seconds: float = 60.0, burst: int = 4) -> None:
        self.capacity = max(1, capacity)
        self.burst = max(1, min(burst, self.capacity))
        self.window_seconds = window_seconds
        self._rooms: Dict[str, List[float]] = {}

    def _prune(self, room: str, now: float) -> None:
        cutoff = now - self.window_seconds
        self._rooms[room] = [t for t in self._rooms.get(room, []) if t > cutoff]

    def can_consume(self, room: str) -> bool:
        """True if one more token may be spent for ``room`` right now."""
        now = time.monotonic()
        self._prune(room, now)
        return len(self._rooms.get(room, [])) < self.burst

    def consume(self, room: str) -> None:
        now = time.monotonic()
        self._prune(room, now)
        self._rooms.setdefault(room, []).append(now)
        # Hard cap on stored timestamps so a chatty room can't grow memory.
        if len(self._rooms[room]) > self.capacity * 4:
            drop = len(self._rooms[room]) - self.capacity * 4
            del self._rooms[room][:drop]

    def wait_time(self, room: str, now: Optional[float] = None) -> float:
        """Seconds until the earliest token in the window expires (0 if free)."""
        now = now if now is not None else time.monotonic()
        self._prune(room, now)
        if not self._rooms.get(room):
            return 0.0
        return max(0.0, self._rooms[room][0] + self.window_seconds - now)


# --------------------------------------------------------------------------- #
# Image handling
# --------------------------------------------------------------------------- #


async def _download_image(client: nio.AsyncClient, event: nio.RoomMessageImage) -> bytes:
    """Download the image event's media to bytes. Raises RuntimeError on failure."""
    mxc = getattr(event, "url", None)
    if not mxc:
        raise RuntimeError("image event has no media URL")
    resp = await client.download(mxc, allow_remote=True)
    if isinstance(resp, nio.DownloadError):
        raise RuntimeError(f"could not download media {mxc!r}: {resp.message}")
    body = getattr(resp, "body", None)
    if body is None:
        raise RuntimeError(f"media download returned no body for {mxc!r}")
    return bytes(body)


def _sender(event: nio.RoomMessageImage) -> str:
    return getattr(event, "sender", "") or ""


def _user_allowed(cfg: BotConfig, sender: str) -> bool:
    if cfg.allowed_users is None:
        return True
    return sender in cfg.allowed_users


async def _send_text(client: nio.AsyncClient, room_id: str, text: str) -> None:
    try:
        await client.room_send(
            room_id,
            "m.room.message",
            {"msgtype": "m.text", "body": text},
        )
    except Exception:  # noqa: BLE001 - never let a reply failure crash the loop
        log.exception("failed to send reply to %s", room_id)


def _friendly_error(exc: ImageAnalysisError) -> str:
    """Map a typed analysis error to a user-facing message."""
    if isinstance(exc, ApiKeyMissingError):
        return (
            "⚠️ I can't analyse images right now: the vision API key is not "
            "configured (OPENROUTER_API_KEY / OPENAI_API_KEY)."
        )
    if isinstance(exc, UnsupportedImageError):
        return f"⚠️ That file isn't a supported image format: {exc}"
    if isinstance(exc, CorruptImageError):
        return f"⚠️ That image looks corrupt or truncated: {exc}"
    if isinstance(exc, VisionAPIError):
        return f"⚠️ The vision model errored: {exc}"
    return f"⚠️ Couldn't analyse that image: {exc}"


async def process_image(
    client: nio.AsyncClient,
    cfg: BotConfig,
    room_id: str,
    event: nio.RoomMessageImage,
    semaphore: asyncio.Semaphore,
    limiter: RateLimiter,
) -> None:
    """Analyze one image and reply in its room. Never raises."""
    if not limiter.can_consume(room_id):
        wait = limiter.wait_time(room_id)
        await _send_text(
            client,
            room_id,
            f"⏳ Too many images — give me a moment, I'll pick this up "
            f"in {max(1, round(wait))}s.",
        )
        return

    limiter.consume(room_id)

    async with semaphore:
        try:
            raw = await _download_image(client, event)
        except (RuntimeError, Exception) as exc:  # noqa: BLE001
            log.warning("download failed in %s: %s", room_id, exc)
            await _send_text(client, room_id, f"⚠️ Couldn't download that image: {exc}")
            return

        try:
            description = await asyncio.to_thread(
                analyze_image,
                raw,
                cfg.prompt,
                # let env supply api_key / model / base_url
            )
        except ImageAnalysisError as exc:
            log.warning("analysis failed in %s: %s", room_id, exc)
            await _send_text(client, room_id, _friendly_error(exc))
            return
        except Exception as exc:  # noqa: BLE001 - unexpected failure path
            log.exception("unexpected analysis failure in %s", room_id)
            await _send_text(
                client,
                room_id,
                f"⚠️ Something unexpected went wrong analysing that: {exc}",
            )
            return

        log.info("analysed image in %s (%s chars)", room_id, len(description))
        await _send_text(client, room_id, description)


# --------------------------------------------------------------------------- #
# Event handlers
# --------------------------------------------------------------------------- #


def _make_handlers(
    cfg: BotConfig,
    semaphore: asyncio.Semaphore,
    limiter: RateLimiter,
):
    async def on_image(room: nio.MatrixRoom, event: nio.RoomMessageImage) -> None:
        room_id = room.room_id
        sender = _sender(event)
        if not _user_allowed(cfg, sender):
            log.info("ignoring image from unallowed user %s in %s", sender, room_id)
            return
        # Don't try to analyse our own replies.
        if sender == cfg.user_id:
            return
        log.info("received m.image in %s from %s", room_id, sender)
        await process_image(client, cfg, room_id, event, semaphore, limiter)

    async def on_encryption(room: nio.MatrixRoom, event: Any) -> None:
        # No libolm in this env — detect encrypted rooms and warn once.
        room_id = room.room_id
        if room_id in _ENCRYPTION_NOTICE_SENT:
            return
        _ENCRYPTION_NOTICE_SENT.add(room_id)
        await _send_text(
            client,
            room_id,
            "🔒 This room is encrypted, but this bot build has no E2EE support. "
            "Please use an unencrypted room to send me images.",
        )

    return on_image, on_encryption


# --------------------------------------------------------------------------- #
# Main loop
# --------------------------------------------------------------------------- #


async def _run(cfg: BotConfig) -> int:
    semaphore = asyncio.Semaphore(cfg.max_concurrent)
    limiter = RateLimiter(capacity=cfg.max_image_rate, burst=cfg.max_image_rate)

    client = nio.AsyncClient(
        cfg.homeserver,
        cfg.user_id,
        device_id=cfg.device_id,
    )

    on_image, on_encryption = _make_handlers(cfg, semaphore, limiter)
    client.add_event_callback(on_image, nio.RoomMessageImage)
    client.add_event_callback(on_encryption, nio.RoomEncryptedMedia)

    login_resp = await client.login(token=cfg.access_token)
    if isinstance(login_resp, nio.LoginError):
        log.error("login failed: %s", login_resp.message)
        return 2

    log.info("connected as %s to %s", cfg.user_id, cfg.homeserver)
    await client.sync_forever(timeout=30000, full_state=False)
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    try:
        cfg = BotConfig.from_env()
    except RuntimeError as exc:
        print(f"matrix-vision-bot: {exc}", file=sys.stderr)
        return 2
    return asyncio.run(_run(cfg))


if __name__ == "__main__":
    raise SystemExit(main())