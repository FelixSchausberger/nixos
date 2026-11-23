"""Open-Meteo weather codes and the on-disk conditions cache."""

from __future__ import annotations

import json
import logging
import os
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable

from .model import WEATHERS, Manifest

LOGGER = logging.getLogger(__name__)

# WMO 4677 codes returned by Open-Meteo's `weather_code`.
WMO_CATEGORIES: dict[int, str] = {
    0: "clear",
    1: "clear",
    2: "partly",
    3: "overcast",
    45: "fog",
    48: "fog",
    51: "rain",
    53: "rain",
    55: "rain",
    56: "rain",
    57: "rain",
    61: "rain",
    63: "rain",
    65: "rain",
    66: "rain",
    67: "rain",
    71: "snow",
    73: "snow",
    75: "snow",
    77: "snow",
    80: "rain",
    81: "rain",
    82: "rain",
    85: "snow",
    86: "snow",
    95: "thunder",
    96: "thunder",
    99: "thunder",
}

# The timer runs every ten minutes; the API is cheap but there is no reason to
# call it more often than the conditions can change.
REFRESH = timedelta(minutes=5)
# When the network is down, keep the last observation for this long before
# falling back to phase and season only.
MAX_AGE = timedelta(hours=6)


@dataclass(frozen=True)
class CachedWeather:
    category: str | None
    fetched_at: datetime


def category_from_code(code: object) -> str | None:
    if isinstance(code, bool) or not isinstance(code, int):
        return None
    return WMO_CATEGORIES.get(code)


def _fetch_json(url: str, timeout: float) -> dict:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "wallpaper-conditions/0.1"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def fetch_category(latitude: float, longitude: float, *, timeout: float = 10.0) -> str | None:
    query = urllib.parse.urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "current": "weather_code",
            "timezone": "auto",
        }
    )
    payload = _fetch_json(f"https://api.open-meteo.com/v1/forecast?{query}", timeout)
    current = payload.get("current")
    if not isinstance(current, dict):
        raise ValueError("Open-Meteo response has no current block")
    return category_from_code(current.get("weather_code"))


def read_cache(path: Path) -> CachedWeather | None:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(raw, dict):
        return None
    category = raw.get("category")
    if category is not None and category not in WEATHERS:
        return None
    try:
        fetched_at = datetime.fromisoformat(raw["fetched_at"])
    except (KeyError, TypeError, ValueError):
        return None
    if fetched_at.tzinfo is None:
        fetched_at = fetched_at.replace(tzinfo=timezone.utc)
    return CachedWeather(category=category, fetched_at=fetched_at)


def write_cache(path: Path, category: str | None, fetched_at: datetime) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps({"category": category, "fetched_at": fetched_at.isoformat()}),
        encoding="utf-8",
    )
    os.replace(temporary, path)


def resolve(
    manifest: Manifest,
    cache_path: Path,
    now: datetime,
    *,
    offline: bool = False,
    fetch: Callable[[float, float], str | None] | None = None,
) -> str | None:
    """Return the current weather category, preferring a fresh cache entry."""

    if not manifest.weather_enabled:
        return None

    cached = read_cache(cache_path)
    if cached is not None and now - cached.fetched_at < REFRESH:
        return cached.category

    if offline:
        if cached is not None and now - cached.fetched_at < MAX_AGE:
            return cached.category
        return None

    fetcher = fetch or fetch_category
    try:
        category = fetcher(manifest.latitude, manifest.longitude)
    except Exception as exc:  # noqa: BLE001 - any network/parse failure means fallback
        LOGGER.warning("weather fetch failed: %s", exc)
    else:
        write_cache(cache_path, category, now)
        return category

    if cached is not None and now - cached.fetched_at < MAX_AGE:
        LOGGER.warning("using cached weather from %s", cached.fetched_at.isoformat())
        return cached.category
    return None
