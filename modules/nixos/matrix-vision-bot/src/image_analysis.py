"""Image analysis module for the Matrix vision bot.

Accepts an image (file path, bytes, or a file-like object) and returns a
textual analysis/description produced by an OpenAI-compatible vision model
(OpenAI, OpenRouter, local vLLM/LLaVA, ...).

Design goals
------------
* Single, clear public entry point: ``analyze_image(...)``.
* All I/O and API calls are intentionally separated so the module is easy to
  unit-test offline (see :func:`_load_image_bytes` / :func:`_normalize_image`).
* Graceful, *typed* error handling for every failure mode:
  unsupported/corrupt input, missing credentials, and upstream API errors.
* Configuration resolved from explicit args first, then environment.

Environment variables (all optional if you pass the value explicitly):
    OPENROUTER_API_KEY / OPENAI_API_KEY  -- provider credential
    OPENROUTER_BASE_URL / OPENAI_BASE_URL-- API base (OpenRouter or self-host)
    OPENAI_MODEL                         -- model id override

Example
-------
    >>> import image_analysis as ia
    >>> ia.analyze_image("photo.jpg")          # uses env credentials
    >>> ia.analyze_image(b"\\xff\\xd8...", api_key="sk-...", model="gpt-4o-mini")
"""

from __future__ import annotations

import base64
import io
import os
import pathlib
import time
from dataclasses import dataclass
from typing import BinaryIO, Optional, Union

from PIL import Image, UnidentifiedImageError
from openai import OpenAI

# --------------------------------------------------------------------------- #
# Public error types
# --------------------------------------------------------------------------- #


class ImageAnalysisError(Exception):
    """Base class for all errors raised by this module."""


class UnsupportedImageError(ImageAnalysisError):
    """The input is a valid image but in an unsupported format."""


class CorruptImageError(ImageAnalysisError):
    """The input bytes/path are not a decodable image (truncated, wrong data)."""


class ApiKeyMissingError(ImageAnalysisError):
    """No API credential was provided and none could be found in the env."""


class VisionAPIError(ImageAnalysisError):
    """The vision provider returned an error after all retries were exhausted."""


# --------------------------------------------------------------------------- #
# Input handling: turn any accepted input into validated, normalized JPEG bytes
# --------------------------------------------------------------------------- #

ImageInput = Union[str, bytes, bytearray, BinaryIO, pathlib.Path]

# Formats Pillow decodes that we consider "supported" for analysis. Anything
# else raises UnsupportedImageError.
_SUPPORTED_FORMATS = {
    "JPEG", "PNG", "WEBP", "GIF", "BMP", "TIFF",
    "HEIC", "HEIF", "ICO", "PPM", "JPG",
}

# Longest side we ship to the API. Downscaling keeps payloads small and lets
# the model see the whole scene. The CLI default (1024) is a good balance.
_DEFAULT_MAX_DIMENSION = 1024
_DEFAULT_JPEG_QUALITY = 85
# Small hard cap so a pathological 200 MP file doesn't OOM us.
_ABSOLUTE_MAX_PIXELS = 40_000_000


def _read_input(input_: ImageInput) -> bytes:
    """Coerce any accepted input type to raw image bytes."""
    if isinstance(input_, pathlib.Path):
        input_ = str(input_)

    if isinstance(input_, (str, bytes, bytearray)):
        if isinstance(input_, str):
            # Treat a string as a filesystem path.
            p = pathlib.Path(input_)
            if not p.exists():
                raise FileNotFoundError(f"image path does not exist: {input_!r}")
            return p.read_bytes()
        return bytes(input_)  # bytes / bytearray already in memory

    # File-like object (e.g. an open file or a BytesIO / an HTTP response body).
    if not hasattr(input_, "read"):
        raise TypeError(
            f"unsupported image input of type {type(input_).__name__}; "
            "expected str path, bytes, bytearray, or a file-like object"
        )
    data = input_.read()
    if not isinstance(data, bytes):
        raise TypeError(
            f"file-like object .read() returned {type(data).__name__}, "
            "expected bytes"
        )
    return data


def _decode_image(raw: bytes) -> Image.Image:
    """Decode raw bytes and validate format/size, raising typed errors."""
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()  # forces full decode so truncated/corrupt data raises here
    except UnidentifiedImageError as exc:
        raise UnsupportedImageError(
            "input is not a decodable image (wrong type or unrecognized "
            "container)"
        ) from exc
    except OSError as exc:
        raise CorruptImageError(f"image data is corrupt or truncated: {exc}") from exc

    fmt = (img.format or "").upper()
    if fmt not in _SUPPORTED_FORMATS:
        raise UnsupportedImageError(
            f"unsupported image format: {fmt or '?'}. "
            f"Supported: {sorted(_SUPPORTED_FORMATS)}"
        )

    w, h = img.size
    if w * h > _ABSOLUTE_MAX_PIXELS:
        raise CorruptImageError(
            f"image too large ({w}x{h} = {w*h:,} px > {_ABSOLUTE_MAX_PIXELS:,} "
            "px cap)"
        )
    return img


def _normalize_image(img: Image.Image, max_dimension: int) -> bytes:
    """Downscale, convert to RGB, and re-encode as JPEG bytes (payload-ready).

    Returns the encoded JPEG bytes; used both by :func:`analyze_image` and by
    the offline tests. Alpha layers are flattened onto white.
    """
    w, h = img.size
    longest = max(w, h)
    if longest > max_dimension:
        ratio = max_dimension / longest
        img = img.resize(
            (max(1, round(w * ratio)), max(1, round(h * ratio))),
            Image.LANCZOS,
        )

    if img.mode == "RGBA":
        rgba = img.convert("RGBA")
        bg = Image.new("RGB", rgba.size, (255, 255, 255))
        bg.paste(rgba, mask=rgba.split()[-1])
        img = bg
    elif img.mode != "RGB":
        img = img.convert("RGB")

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=_DEFAULT_JPEG_QUALITY)
    return buf.getvalue()


def _to_data_url(jpeg: bytes) -> str:
    """Build the data: URL the vision API expects for an image part."""
    return "data:image/jpeg;base64," + base64.b64encode(jpeg).decode("ascii")


# --------------------------------------------------------------------------- #
# Configuration resolution
# --------------------------------------------------------------------------- #

_DEFAULT_DESCRIPTION_PROMPT = (
    "Describe this image in detail. Cover the main subject, the scene, any "
    "visible text, colors, and notable details. Keep it factual and concise."
)


@dataclass(frozen=True)
class _Config:
    model: str
    api_key: str
    base_url: Optional[str]
    timeout: float


def _resolve_config(
    *,
    model: Optional[str],
    api_key: Optional[str],
    base_url: Optional[str],
    timeout: float,
) -> _Config:
    key = api_key or os.getenv("OPENROUTER_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not key:
        raise ApiKeyMissingError(
            "no API credential available. Pass api_key=..., or set "
            "OPENROUTER_API_KEY / OPENAI_API_KEY."
        )

    resolved_base = (
        base_url
        or os.getenv("OPENROUTER_BASE_URL")
        or os.getenv("OPENAI_BASE_URL")
    )

    # Pick a sensible default model only when the caller didn't override and no
    # env model is set. Prefer OpenRouter's key namespace when that's the cred
    # in use, because bare OpenAI model names fail against OpenRouter.
    env_model = os.getenv("OPENAI_MODEL")
    if model:
        pass
    elif env_model:
        model = env_model
    elif os.getenv("OPENROUTER_API_KEY") or resolved_base and "openrouter" in resolved_base:
        model = "openai/gpt-4o-mini"
    else:
        model = "gpt-4o-mini"

    resolved_base = resolved_base or None  # let the SDK default to api.openai.com
    return _Config(model=model, api_key=key, base_url=resolved_base, timeout=timeout)


# --------------------------------------------------------------------------- #
# The public API
# --------------------------------------------------------------------------- #


def prepare_image(
    input_: ImageInput, max_dimension: int = _DEFAULT_MAX_DIMENSION
) -> bytes:
    """Validate + normalize an image and return payload-ready JPEG bytes.

    This is the offline half of ``analyze_image`` — no network is touched.
    Raises UnsupportedImageError / CorruptImageError / FileNotFoundError /
    TypeError on bad input.
    """
    raw = _read_input(input_)
    img = _decode_image(raw)
    return _normalize_image(img, max_dimension)


def analyze_image(
    input_: ImageInput,
    prompt: Optional[str] = None,
    *,
    model: Optional[str] = None,
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    timeout: float = 60.0,
    max_retries: int = 2,
    max_dimension: int = _DEFAULT_MAX_DIMENSION,
) -> str:
    """Analyze an image and return a textual description.

    Parameters
    ----------
    input_ : str | bytes | bytearray | BufferedIOBase | Path
        Path to an image, raw image bytes, or an open file-like object.
    prompt : str, optional
        The instruction sent to the model. Defaults to a generic description
        prompt (see ``_DEFAULT_DESCRIPTION_PROMPT``).
    model : str, optional
        Vision model id (e.g. ``"gpt-4o-mini"``, ``"openai/gpt-4o-mini"``).
        Falls back to ``$OPENAI_MODEL`` then a provider-appropriate default.
    api_key : str, optional
        Credential. Falls back to ``$OPENROUTER_API_KEY`` then ``$OPENAI_API_KEY``.
    base_url : str, optional
        OpenAI-compatible endpoint. Falls back to
        ``$OPENROUTER_BASE_URL`` then ``$OPENAI_BASE_URL``.
    timeout : float
        Per-attempt HTTP timeout in seconds.
    max_retries : int
        Number of *retries* (beyond the first attempt) for transient failures.
    max_dimension : int
        Longest side, in pixels, the image is downscaled to before upload.

    Returns
    -------
    str
        The model's textual analysis of the image.

    Raises
    ------
    UnsupportedImageError, CorruptImageError
        The input is not a usable image.
    FileNotFoundError, TypeError
        The input path/type is invalid.
    ApiKeyMissingError
        No credential supplied or available in the environment.
    VisionAPIError
        The provider failed after all retries.
    """
    jpeg = prepare_image(input_, max_dimension=max_dimension)

    cfg = _resolve_config(
        model=model, api_key=api_key, base_url=base_url, timeout=timeout
    )
    client = OpenAI(api_key=cfg.api_key, base_url=cfg.base_url, timeout=cfg.timeout)

    content = [
        {
            "type": "image_url",
            "image_url": {"url": _to_data_url(jpeg)},
        },
        {"type": "text", "text": prompt or _DEFAULT_DESCRIPTION_PROMPT},
    ]

    last_exc: Optional[Exception] = None
    for attempt in range(1 + max_retries):
        try:
            resp = client.chat.completions.create(
                model=cfg.model,
                messages=[{"role": "user", "content": content}],
                max_tokens=1024,
            )
        except Exception as exc:  # noqa: BLE001 - normalize every SDK failure
            last_exc = exc
            # Backoff before retrying; skip on the final attempt.
            if attempt < max_retries:
                time.sleep(min(2 ** attempt, 8))
            continue

        text = (resp.choices[0].message.content or "").strip()
        if not text:
            raise VisionAPIError("vision model returned an empty response")
        return text

    raise VisionAPIError(
        f"vision API call failed after {1 + max_retries} attempt(s): {last_exc}"
    )