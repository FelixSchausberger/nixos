"""Manifest types and validation for condition-aware wallpaper selection."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

PHASES = ("dawn", "day", "dusk", "night")
WEATHERS = ("clear", "partly", "overcast", "fog", "rain", "snow", "thunder")
DIMENSIONS = ("phase", "weather")
IMAGE_SUFFIXES = frozenset({".jpg", ".jpeg", ".png", ".webp"})
COLLECTION_NAME_RE = re.compile(r"^[A-Za-z0-9_-]+$")
DEFAULT_INTERVAL_SECONDS = 3600


class ManifestError(ValueError):
    """Raised when the generated manifest is missing or malformed."""


@dataclass(frozen=True)
class Collection:
    """One folder of wallpapers and the conditions it is valid for.

    An empty predicate set means the collection matches every condition; it is
    the fallback and ranks below every constrained collection.
    """

    name: str
    phase: frozenset[str] = frozenset()
    weather: frozenset[str] = frozenset()
    priority: int = 0

    def matches(self, *, phase: str, weather: str | None) -> bool:
        if self.phase and phase not in self.phase:
            return False
        if self.weather and (weather is None or weather not in self.weather):
            return False
        return True

    @property
    def specificity(self) -> int:
        return sum(1 for values in (self.phase, self.weather) if values)


@dataclass(frozen=True)
class Manifest:
    roots: tuple[Path, ...]
    latitude: float
    longitude: float
    weather_enabled: bool
    order: tuple[str, ...]
    collections: tuple[Collection, ...]
    fallback_file: Path
    fallback_blurred: Path | None
    publish: Path | None = None
    interval_seconds: int = DEFAULT_INTERVAL_SECONDS


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ManifestError(message)


def _string_list(raw: Any, field: str) -> list[str]:
    _require(isinstance(raw, list), f"{field} must be a list")
    _require(all(isinstance(value, str) for value in raw), f"{field} must contain strings")
    return raw


def _values(raw: Any, allowed: tuple[str, ...], field: str) -> frozenset[str]:
    values = _string_list(raw, field)
    unknown = sorted(set(values) - set(allowed))
    _require(not unknown, f"{field} has unknown values {unknown}; allowed: {list(allowed)}")
    return frozenset(values)


def _number(raw: Any, field: str, minimum: float, maximum: float) -> float:
    _require(
        isinstance(raw, (int, float)) and not isinstance(raw, bool),
        f"{field} must be a number",
    )
    _require(minimum <= float(raw) <= maximum, f"{field} must be between {minimum} and {maximum}")
    return float(raw)


def _absolute_path(raw: Any, field: str) -> Path:
    _require(isinstance(raw, str) and raw != "", f"{field} must be a non-empty string")
    path = Path(raw)
    _require(path.is_absolute(), f"{field} must be an absolute path: {raw}")
    return path


def load_manifest(path: Path) -> Manifest:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ManifestError(f"cannot read manifest {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"manifest {path} is not valid JSON: {exc}") from exc

    _require(isinstance(raw, dict), "manifest must be a JSON object")

    roots_raw = _string_list(raw.get("roots"), "roots")
    _require(bool(roots_raw), "roots must not be empty")
    roots = tuple(_absolute_path(root, "roots entry") for root in roots_raw)

    latitude = _number(raw.get("latitude"), "latitude", -90.0, 90.0)
    longitude = _number(raw.get("longitude"), "longitude", -180.0, 180.0)

    weather_enabled = raw.get("weather", True)
    _require(isinstance(weather_enabled, bool), "weather must be a boolean")

    order_raw = raw.get("order", list(DIMENSIONS))
    _require(
        isinstance(order_raw, list) and sorted(order_raw) == sorted(DIMENSIONS),
        f"order must be a permutation of {list(DIMENSIONS)}",
    )
    order = tuple(order_raw)

    collections_raw = raw.get("collections")
    _require(isinstance(collections_raw, dict), "collections must be an object")
    collections = []
    for name, spec in collections_raw.items():
        _require(
            isinstance(name, str) and COLLECTION_NAME_RE.fullmatch(name) is not None,
            f"invalid collection name {name!r}; use letters, digits, '_' and '-'",
        )
        _require(isinstance(spec, dict), f"collection {name} must be an object")
        unknown = sorted(set(spec) - set(DIMENSIONS) - {"priority"})
        _require(not unknown, f"collection {name} has unknown keys {unknown}")
        priority = spec.get("priority", 0)
        _require(
            isinstance(priority, int) and not isinstance(priority, bool),
            f"{name}.priority must be an integer",
        )
        collections.append(
            Collection(
                name=name,
                phase=_values(spec.get("phase", []), PHASES, f"{name}.phase"),
                weather=_values(spec.get("weather", []), WEATHERS, f"{name}.weather"),
                priority=priority,
            )
        )

    fallback_raw = raw.get("fallback")
    _require(isinstance(fallback_raw, dict), "fallback must be an object")
    fallback_file = _absolute_path(fallback_raw.get("file"), "fallback.file")
    blurred_raw = fallback_raw.get("blurred")
    fallback_blurred = _absolute_path(blurred_raw, "fallback.blurred") if blurred_raw is not None else None
    publish_raw = raw.get("publish")
    publish = _absolute_path(publish_raw, "publish") if publish_raw is not None else None
    interval_raw = raw.get("interval", DEFAULT_INTERVAL_SECONDS)
    _require(
        isinstance(interval_raw, int)
        and not isinstance(interval_raw, bool)
        and interval_raw > 0,
        "interval must be a positive integer of seconds",
    )

    return Manifest(
        roots=roots,
        latitude=latitude,
        longitude=longitude,
        weather_enabled=weather_enabled,
        order=order,
        collections=tuple(collections),
        fallback_file=fallback_file,
        fallback_blurred=fallback_blurred,
        publish=publish,
        interval_seconds=interval_raw,
    )
