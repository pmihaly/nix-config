"""matrix-vision-bot package.

Provides image analysis on top of any OpenAI-compatible vision endpoint
(OpenAI, OpenRouter, local vLLM/LLaVA). The runtime is the pinned Nix
environment from this flake.

Public API
----------
    analyze_image(input_, ...) -> str
        Full pipeline: validate + normalize the image offline, then ask a
        vision model for a textual analysis. Raises typed errors
        (UnsupportedImageError / CorruptImageError / ApiKeyMissingError /
        VisionAPIError) on bad input or upstream failure.
    prepare_image(input_, ...) -> bytes
        Offline half only: return payload-ready JPEG bytes (no network).
"""

from .image_analysis import (
    ApiKeyMissingError,
    CorruptImageError,
    ImageAnalysisError,
    UnsupportedImageError,
    VisionAPIError,
    analyze_image,
    prepare_image,
)

__all__ = [
    "analyze_image",
    "prepare_image",
    "ImageAnalysisError",
    "UnsupportedImageError",
    "CorruptImageError",
    "ApiKeyMissingError",
    "VisionAPIError",
]
