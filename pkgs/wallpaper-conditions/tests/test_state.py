from __future__ import annotations

import tempfile
import unittest
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from wallpaper_conditions.model import Collection
from wallpaper_conditions.resolve import Match, Resolution
from wallpaper_conditions.state import (
    State,
    choose_file,
    load,
    roll_date,
    save,
    stabilize_weather,
)

NOW = datetime(2026, 11, 23, 12, 0, tzinfo=timezone.utc)
FILES = (Path("/wallpapers/night/a.jpg"), Path("/wallpapers/night/b.jpg"))


def make_resolution(name: str, files: tuple[Path, ...] = FILES) -> Resolution:
    collection = Collection(name)
    match = Match(collection=collection, files=files, rank=0, specificity=0)
    return Resolution(
        phase="night",
        weather=None,
        matches=(match,),
        chosen=match,
        fallback_file=Path("/fallback.jpg"),
        fallback_blurred=Path("/fallback_blurred.jpg"),
    )


def fallback_resolution() -> Resolution:
    return Resolution(
        phase="day",
        weather=None,
        matches=(),
        chosen=None,
        fallback_file=Path("/fallback.jpg"),
        fallback_blurred=Path("/fallback_blurred.jpg"),
    )


class SelectionTests(unittest.TestCase):
    def test_first_pick_sets_state(self) -> None:
        state = State()
        chosen = choose_file(state, make_resolution("night"), NOW, choice=lambda seq: seq[0])
        self.assertEqual(chosen, FILES[0])
        self.assertEqual(state.collection, "night")
        self.assertEqual(state.selected_file, str(FILES[0]))
        self.assertEqual(state.selected_at, NOW.isoformat())

    def test_sticky_within_the_same_day(self) -> None:
        state = State(
            collection="night",
            selected_file=str(FILES[0]),
            selected_at=NOW.isoformat(),
        )
        chosen = choose_file(
            state,
            make_resolution("night"),
            NOW + timedelta(hours=1),
            choice=lambda _seq: FILES[1],
        )
        self.assertEqual(chosen, FILES[0])
        self.assertEqual(state.selected_file, str(FILES[0]))

    def test_daily_reroll_excludes_the_current_image(self) -> None:
        state = State(
            collection="night",
            selected_file=str(FILES[0]),
            selected_at=NOW.isoformat(),
        )
        seen: list[Path] = []

        def choice(candidates):
            seen.extend(candidates)
            return candidates[0]

        chosen = choose_file(state, make_resolution("night"), NOW + timedelta(days=1), choice=choice)
        self.assertEqual(chosen, FILES[1])
        self.assertEqual(seen, [FILES[1]])
        self.assertEqual(state.selected_at, (NOW + timedelta(days=1)).isoformat())

    def test_reroll_flag_picks_a_new_image(self) -> None:
        state = State(
            collection="night",
            selected_file=str(FILES[0]),
            selected_at=NOW.isoformat(),
        )
        chosen = choose_file(
            state,
            make_resolution("night"),
            NOW,
            reroll=True,
            choice=lambda _seq: FILES[1],
        )
        self.assertEqual(chosen, FILES[1])

    def test_missing_current_file_repicks(self) -> None:
        state = State(
            collection="night",
            selected_file="/wallpapers/night/deleted.jpg",
            selected_at=NOW.isoformat(),
        )
        chosen = choose_file(state, make_resolution("night"), NOW, choice=lambda seq: seq[0])
        self.assertEqual(chosen, FILES[0])

    def test_fallback_selection(self) -> None:
        state = State()
        chosen = choose_file(state, fallback_resolution(), NOW, choice=lambda seq: seq[0])
        self.assertEqual(chosen, Path("/fallback.jpg"))
        self.assertIsNone(state.collection)

    def test_roll_date_anchor(self) -> None:
        self.assertEqual(roll_date(datetime(2026, 11, 23, 3, 0, tzinfo=timezone.utc)), date(2026, 11, 22))
        self.assertEqual(roll_date(datetime(2026, 11, 23, 5, 0, tzinfo=timezone.utc)), date(2026, 11, 23))


class WeatherHysteresisTests(unittest.TestCase):
    def test_initial_category_promotes_immediately(self) -> None:
        state = State()
        self.assertEqual(stabilize_weather(state, "rain", NOW), "rain")
        self.assertEqual(state.weather_effective, "rain")
        self.assertEqual(state.weather_pending, None)

    def test_same_category_clears_pending(self) -> None:
        state = State(weather_effective="rain", weather_since=NOW.isoformat())
        self.assertEqual(stabilize_weather(state, "rain", NOW + timedelta(minutes=10)), "rain")
        self.assertIsNone(state.weather_pending)

    def test_change_needs_two_samples_and_min_dwell(self) -> None:
        state = State(weather_effective="rain", weather_since=NOW.isoformat())
        self.assertEqual(stabilize_weather(state, "snow", NOW + timedelta(minutes=10)), "rain")
        self.assertEqual(state.weather_pending, "snow")
        self.assertEqual(stabilize_weather(state, "snow", NOW + timedelta(minutes=20)), "rain")
        self.assertEqual(stabilize_weather(state, "snow", NOW + timedelta(minutes=30)), "snow")
        self.assertEqual(state.weather_effective, "snow")

    def test_min_dwell_blocks_a_fast_change(self) -> None:
        state = State(weather_effective="rain", weather_since=NOW.isoformat())
        stabilize_weather(state, "snow", NOW + timedelta(minutes=25))
        self.assertEqual(stabilize_weather(state, "snow", NOW + timedelta(minutes=40)), "rain")
        self.assertEqual(stabilize_weather(state, "snow", NOW + timedelta(minutes=45)), "snow")

    def test_unknown_category_keeps_effective(self) -> None:
        state = State(weather_effective="rain", weather_since=NOW.isoformat())
        self.assertEqual(stabilize_weather(state, None, NOW + timedelta(hours=1)), "rain")

    def test_pending_change_is_replaced(self) -> None:
        state = State(weather_effective="rain", weather_since=NOW.isoformat())
        stabilize_weather(state, "snow", NOW + timedelta(minutes=10))
        self.assertEqual(stabilize_weather(state, "fog", NOW + timedelta(minutes=20)), "rain")
        self.assertEqual(state.weather_pending, "fog")


class PersistenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "state.json"

    def test_roundtrip(self) -> None:
        state = State(
            collection="rain",
            selected_file="/wallpapers/rain/a.jpg",
            applied_file="/wallpapers/rain/a.jpg",
            selected_at=NOW.isoformat(),
            weather_effective="rain",
            weather_since=NOW.isoformat(),
        )
        save(self.path, state)
        self.assertEqual(load(self.path), state)

    def test_missing_file_is_empty_state(self) -> None:
        self.assertEqual(load(self.path), State())

    def test_corrupt_file_is_empty_state(self) -> None:
        self.path.write_text("{not json", encoding="utf-8")
        self.assertEqual(load(self.path), State())

    def test_invalid_field_types_are_empty_state(self) -> None:
        self.path.write_text('{"collection": 42}', encoding="utf-8")
        self.assertEqual(load(self.path), State())


if __name__ == "__main__":
    unittest.main()
