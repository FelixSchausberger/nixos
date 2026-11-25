"""Sticky selection state and weather hysteresis."""

from __future__ import annotations

import json
import logging
import os
import random
from dataclasses import asdict, dataclass, fields
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, Sequence

from .resolve import Resolution

LOGGER = logging.getLogger(__name__)

# An image is re-rolled once per interval. The weather category must be
# observed twice with a minimum dwell before it replaces the effective
# category: short enough to follow real conditions, long enough that a passing
# shower cannot flip the wallpaper twice.
DEFAULT_INTERVAL = timedelta(hours=1)
WEATHER_HYSTERESIS = timedelta(minutes=20)
WEATHER_MIN_DWELL = timedelta(minutes=30)


@dataclass
class State:
    collection: str | None = None
    selected_file: str | None = None
    applied_file: str | None = None
    published_file: str | None = None
    selected_at: str | None = None
    weather_effective: str | None = None
    weather_since: str | None = None
    weather_pending: str | None = None
    weather_pending_since: str | None = None

    @classmethod
    def from_json(cls, raw: object) -> "State":
        if not isinstance(raw, dict):
            return cls()
        values = {}
        for field in fields(cls):
            value = raw.get(field.name)
            if value is not None and not isinstance(value, str):
                return cls()
            values[field.name] = value
        return cls(**values)


def load(path: Path) -> State:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return State()
    except (OSError, json.JSONDecodeError) as exc:
        LOGGER.warning("ignoring unreadable state %s: %s", path, exc)
        return State()
    return State.from_json(raw)


def save(path: Path, state: State) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(asdict(state), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def _parse(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def roll_due(now: datetime, selected_at: datetime, interval: timedelta) -> bool:
    return now - selected_at >= interval


def choose_file(
    state: State,
    resolution: Resolution,
    now: datetime,
    *,
    reroll: bool = False,
    interval: timedelta = DEFAULT_INTERVAL,
    choice: Callable[[Sequence[Path]], Path] = random.choice,
) -> Path:
    files = resolution.files
    current = Path(state.selected_file) if state.selected_file else None
    selected_at = _parse(state.selected_at)
    same_collection = state.collection == resolution.collection_name

    must_pick = (
        reroll
        or not same_collection
        or current is None
        or current not in files
        or selected_at is None
        or roll_due(now, selected_at, interval)
    )
    if not must_pick:
        return current

    candidates = [path for path in files if path != current] or list(files)
    chosen = choice(candidates)
    state.collection = resolution.collection_name
    state.selected_file = str(chosen)
    state.selected_at = now.isoformat()
    return chosen


def stabilize_weather(state: State, raw: str | None, now: datetime) -> str | None:
    """Apply hysteresis and return the category the resolver should use."""

    if raw is None:
        return state.weather_effective

    if state.weather_effective is None:
        state.weather_effective = raw
        state.weather_since = now.isoformat()
        state.weather_pending = None
        state.weather_pending_since = None
        return raw

    if raw == state.weather_effective:
        state.weather_pending = None
        state.weather_pending_since = None
        return raw

    if raw != state.weather_pending:
        state.weather_pending = raw
        state.weather_pending_since = now.isoformat()
        return state.weather_effective

    pending_since = _parse(state.weather_pending_since)
    effective_since = _parse(state.weather_since)
    if pending_since is None:
        state.weather_pending_since = now.isoformat()
        return state.weather_effective

    if now - pending_since >= WEATHER_HYSTERESIS and (
        effective_since is None or now - effective_since >= WEATHER_MIN_DWELL
    ):
        state.weather_effective = raw
        state.weather_since = now.isoformat()
        state.weather_pending = None
        state.weather_pending_since = None
        return raw

    return state.weather_effective
