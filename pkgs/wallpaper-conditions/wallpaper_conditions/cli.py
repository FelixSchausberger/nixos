"""Command line entry point for condition-aware wallpaper selection."""

from __future__ import annotations

import argparse
import fcntl
import json
import logging
import os
from collections import Counter
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterator

from . import __version__
from .apply import ApplyError, apply, backend_ready, publish_current
from .library import Library, scan
from .model import PHASES, WEATHERS, Manifest, ManifestError, load_manifest
from .resolve import Resolution, resolve
from .solar import elevation_degrees, phase
from .state import State, choose_file, load, save, stabilize_weather
from .weather import CachedWeather, read_cache
from .weather import resolve as resolve_weather

LOGGER = logging.getLogger("wallpaper_conditions")


@dataclass(frozen=True)
class Plan:
    manifest: Manifest
    resolution: Resolution
    state: State
    chosen: Path
    raw_weather: str | None
    effective_weather: str | None
    weather_cached: CachedWeather | None
    solar_elevation: float
    now: datetime
    library: Library


def _cache_dir(raw: Path | None) -> Path:
    if raw is not None:
        return raw
    base = os.environ.get("XDG_CACHE_HOME")
    if base:
        return Path(base) / "wallpaper-conditions"
    return Path.home() / ".cache" / "wallpaper-conditions"


def _parse_now(raw: str | None) -> datetime:
    if raw is None:
        return datetime.now().astimezone()
    parsed = datetime.fromisoformat(raw)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=datetime.now().astimezone().tzinfo)
    return parsed


@contextmanager
def _locked(cache_dir: Path) -> Iterator[None]:
    cache_dir.mkdir(parents=True, exist_ok=True)
    with (cache_dir / "lock").open("a", encoding="utf-8") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def _build_plan(
    manifest: Manifest,
    state: State,
    now: datetime,
    cache_dir: Path,
    *,
    offline: bool,
    reroll: bool,
) -> Plan:
    library = scan(manifest)
    local_solar_elevation = elevation_degrees(now, manifest.latitude, manifest.longitude)
    local_phase = phase(now, manifest.latitude, manifest.longitude)
    raw_weather = resolve_weather(
        manifest,
        cache_dir / "weather.json",
        now,
        offline=offline,
    )
    effective_weather = stabilize_weather(state, raw_weather, now)
    resolution = resolve(
        manifest,
        library,
        phase=local_phase,
        weather=effective_weather,
    )
    chosen = choose_file(
        state,
        resolution,
        now,
        reroll=reroll,
        interval=timedelta(seconds=manifest.interval_seconds),
    )
    return Plan(
        manifest=manifest,
        resolution=resolution,
        state=state,
        chosen=chosen,
        raw_weather=raw_weather,
        effective_weather=effective_weather,
        weather_cached=read_cache(cache_dir / "weather.json"),
        solar_elevation=local_solar_elevation,
        now=now,
        library=library,
    )


def _age(now: datetime, then: datetime | None) -> str:
    if then is None:
        return "never"
    seconds = int((now - then).total_seconds())
    if seconds < 60:
        return f"{seconds}s ago"
    if seconds < 3600:
        return f"{seconds // 60}m ago"
    return f"{seconds // 3600}h ago"


def _publish(state: State, chosen: Path, publish: Path | None) -> None:
    """Keep the consumer copy in step with the selection.

    Publication is deliberately independent of the display backend: the
    homepage and the kiosk must follow the conditions even when no awww daemon
    is running. A failed publish leaves the previous image in place.
    """

    if publish is None:
        return
    target = str(chosen)
    if state.published_file == target and publish.exists():
        return
    if publish_current(chosen, publish):
        state.published_file = target


def command_apply(args: argparse.Namespace, manifest: Manifest) -> int:
    cache_dir = _cache_dir(args.cache_dir)
    now = _parse_now(args.now)
    state_path = cache_dir / "state.json"

    with _locked(cache_dir):
        state = load(state_path)
        plan = _build_plan(
            manifest,
            state,
            now,
            cache_dir,
            offline=False,
            reroll=args.reroll,
        )

        if args.dry_run:
            apply(plan.resolution, plan.chosen, cache_dir, dry_run=True)
            return 0

        chosen = str(plan.chosen)
        if not args.force and state.applied_file == chosen:
            LOGGER.debug("already applied: %s", plan.chosen)
        else:
            try:
                result = apply(plan.resolution, plan.chosen, cache_dir)
            except ApplyError:
                # Keep the selection and weather hysteresis but leave
                # applied_file untouched so the next timer tick retries the
                # same image.
                save(state_path, state)
                raise

            if result.applied:
                state.applied_file = chosen
                LOGGER.info("%s", result.reason)
            else:
                LOGGER.info("%s; not applied", result.reason)

        _publish(state, plan.chosen, plan.manifest.publish)
        save(state_path, state)

    return 0


def command_next(args: argparse.Namespace, manifest: Manifest) -> int:
    args.force = True
    args.reroll = True
    return command_apply(args, manifest)


def command_status(args: argparse.Namespace, manifest: Manifest) -> int:
    cache_dir = _cache_dir(args.cache_dir)
    now = _parse_now(args.now)
    state = load(cache_dir / "state.json")
    plan = _build_plan(
        manifest,
        state,
        now,
        cache_dir,
        offline=args.offline,
        reroll=False,
    )

    cached_at = plan.weather_cached.fetched_at if plan.weather_cached is not None else None
    payload = {
        "now": plan.now.isoformat(),
        "phase": plan.resolution.phase,
        "solar_elevation_degrees": round(plan.solar_elevation, 2),
        "weather": {
            "raw": plan.raw_weather,
            "effective": plan.effective_weather,
            "cached_at": cached_at.isoformat() if cached_at is not None else None,
            "offline": args.offline,
        },
        "collection": plan.resolution.collection_name,
        "file": str(plan.chosen),
        "applied_file": plan.state.applied_file,
        "matches": [
            {
                "name": match.collection.name,
                "specificity": match.specificity,
                "rank": match.rank,
                "files": len(match.files),
            }
            for match in plan.resolution.matches
        ],
        "roots": [str(root) for root in plan.manifest.roots],
        "missing_roots": [str(root) for root in plan.library.missing_roots],
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    print(f"now:     {plan.now.isoformat()}")
    print(f"phase:   {plan.resolution.phase} (sun {plan.solar_elevation:.1f} deg)")
    print(
        "weather: "
        f"raw={plan.raw_weather} effective={plan.effective_weather} "
        f"cached={_age(plan.now, cached_at)}"
    )
    if plan.resolution.chosen is not None:
        chosen = plan.resolution.chosen
        print(
            f"folder:  {chosen.collection.name} "
            f"(specificity {chosen.specificity}, rank {chosen.rank}, "
            f"{len(chosen.files)} images)"
        )
    else:
        print("folder:  fallback (no collection matched)")
    print(f"file:    {plan.chosen}")
    print(f"applied: {plan.state.applied_file or 'never'}")
    if plan.resolution.matches:
        print("matches:")
        for match in plan.resolution.matches:
            print(
                f"  {match.collection.name:<24} "
                f"specificity {match.specificity}  rank {match.rank}  "
                f"{len(match.files)} images"
            )
    for root in plan.manifest.roots:
        print(f"root {root}: {'ok' if root.is_dir() else 'MISSING'}")
    print(f"backend: {'ready' if backend_ready() else 'not running'}")
    return 0


def command_doctor(args: argparse.Namespace, manifest: Manifest) -> int:
    library = scan(manifest)
    print(f"manifest: {args.manifest}")
    for root in manifest.roots:
        print(f"root {root}: {'ok' if root.is_dir() else 'MISSING'}")
    for collection in manifest.collections:
        files = library.get(collection.name)
        print(f"collection {collection.name}: {len(files)} images")
        if not files:
            print("  empty or missing")
        for path in files:
            try:
                size = path.stat().st_size
            except OSError:
                continue
            if size > 8 * 1024 * 1024:
                print(
                    f"  warning: {path} is {size // (1024 * 1024)} MiB; "
                    "consider a compressed copy"
                )
    for path in library.unknown_dirs:
        print(f"undeclared folder (ignored): {path}")
    for path in library.missing_roots:
        print(f"missing root: {path}")

    # Enumerate the whole condition space to catch a collection that is always
    # shadowed by a more specific or earlier-ranked one.
    wins: Counter[str] = Counter()
    for candidate_phase in PHASES:
        for candidate_weather in (*WEATHERS, None):
            result = resolve(
                manifest,
                library,
                phase=candidate_phase,
                weather=candidate_weather,
            )
            if result.chosen is not None:
                wins[result.chosen.collection.name] += 1
    for collection in manifest.collections:
        if wins[collection.name] == 0 and library.get(collection.name):
            print(
                f"warning: collection {collection.name} never wins; "
                "it is shadowed by another collection"
            )

    print(f"backend: {'ready' if backend_ready() else 'not running'}")
    return 0


def command_version(_args: argparse.Namespace, _manifest: Manifest) -> int:
    print(__version__)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="wallpaper-conditions",
        description="Select a wallpaper folder by solar phase and weather.",
    )
    parser.add_argument("--manifest", type=Path, help="generated collection manifest")
    parser.add_argument("--cache-dir", type=Path, help="state and weather cache directory")
    parser.add_argument("--now", help="override the clock with an ISO 8601 timestamp")
    parser.add_argument("--verbose", action="store_true", help="debug logging")

    subparsers = parser.add_subparsers(dest="command", required=True)

    apply_parser = subparsers.add_parser("apply", help="resolve and apply a wallpaper")
    apply_parser.add_argument("--force", action="store_true", help="apply even if already applied")
    apply_parser.add_argument("--reroll", action="store_true", help="pick a new image in the folder")
    apply_parser.add_argument("--dry-run", action="store_true", help="print the awww commands")
    apply_parser.set_defaults(func=command_apply)

    next_parser = subparsers.add_parser("next", help="pick and apply a new image now")
    next_parser.add_argument("--dry-run", action="store_true", help="print the awww commands")
    next_parser.set_defaults(func=command_next)

    status_parser = subparsers.add_parser("status", help="explain the current selection")
    status_parser.add_argument("--json", action="store_true", help="machine-readable output")
    status_parser.add_argument("--offline", action="store_true", help="use only the weather cache")
    status_parser.set_defaults(func=command_status)

    doctor_parser = subparsers.add_parser("doctor", help="validate roots, folders and coverage")
    doctor_parser.set_defaults(func=command_doctor)

    version_parser = subparsers.add_parser("version", help="print the version")
    version_parser.set_defaults(func=command_version)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(message)s",
    )

    manifest_raw = args.manifest or os.environ.get("WALLPAPER_CONDITIONS_MANIFEST")
    if not manifest_raw:
        parser.error("--manifest is required (or set WALLPAPER_CONDITIONS_MANIFEST)")

    try:
        manifest = load_manifest(Path(manifest_raw))
        return args.func(args, manifest)
    except (ManifestError, ApplyError, OSError) as exc:
        LOGGER.error("%s", exc)
        return 1
