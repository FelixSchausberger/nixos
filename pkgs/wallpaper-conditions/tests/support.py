"""Shared helpers for the wallpaper-conditions tests."""

from __future__ import annotations

import json
from pathlib import Path


def write_manifest(
    path: Path,
    collections: dict,
    *,
    roots: list[Path],
    weather: bool = False,
    order: list[str] | None = None,
    fallback_file: Path | None = None,
    fallback_blurred: Path | None = None,
    publish: Path | None = None,
    interval: int | None = None,
    themes: dict | None = None,
    default_theme: str | None = None,
    active_theme_file: Path | None = None,
) -> Path:
    payload = {
        "roots": [str(root) for root in roots],
        "latitude": 48.2082,
        "longitude": 16.3738,
        "weather": weather,
        "order": order or ["phase", "weather"],
        "fallback": {
            "file": str(fallback_file or (path.parent / "fallback.jpg")),
            "blurred": str(fallback_blurred or (path.parent / "fallback_blurred.jpg")),
        },
    }
    if themes is None:
        payload["collections"] = collections
    else:
        payload["themes"] = themes
        if default_theme is not None:
            payload["default_theme"] = default_theme
    if publish is not None:
        payload["publish"] = str(publish)
    if interval is not None:
        payload["interval"] = interval
    if active_theme_file is not None:
        payload["active_theme_file"] = str(active_theme_file)
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def touch(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"image")
    return path
