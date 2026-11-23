"""Solar phase and season classification."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from astral import Observer
from astral.sun import elevation

# Civil twilight is the visible dawn/dusk window. Below it the scene reads as
# night, which is also the safe boundary at high latitudes: elevation is always
# defined, unlike sunrise/sunset events that can be absent for a whole day.
TWILIGHT_ELEVATION = -6.0

SEASONS = {
    12: "winter",
    1: "winter",
    2: "winter",
    3: "spring",
    4: "spring",
    5: "spring",
    6: "summer",
    7: "summer",
    8: "summer",
    9: "autumn",
    10: "autumn",
    11: "autumn",
}


def elevation_degrees(now: datetime, latitude: float, longitude: float) -> float:
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    observer = Observer(latitude=latitude, longitude=longitude)
    return elevation(observer, now.astimezone(timezone.utc))


def phase(now: datetime, latitude: float, longitude: float) -> str:
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    observer = Observer(latitude=latitude, longitude=longitude)
    current = now.astimezone(timezone.utc)
    current_elevation = elevation(observer, current)
    if current_elevation >= 0:
        return "day"
    if current_elevation <= TWILIGHT_ELEVATION:
        return "night"
    previous_elevation = elevation(observer, current - timedelta(minutes=1))
    return "dawn" if current_elevation > previous_elevation else "dusk"


def season(now: datetime) -> str:
    return SEASONS[now.month]
