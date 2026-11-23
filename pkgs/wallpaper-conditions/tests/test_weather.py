from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import Mock

from support import write_manifest
from wallpaper_conditions.model import load_manifest
from wallpaper_conditions.weather import (
    category_from_code,
    read_cache,
    resolve,
    write_cache,
)

NOW = datetime(2026, 11, 23, 12, 0, tzinfo=timezone.utc)


class WeatherCodeTests(unittest.TestCase):
    def test_categories(self) -> None:
        self.assertEqual(category_from_code(0), "clear")
        self.assertEqual(category_from_code(1), "clear")
        self.assertEqual(category_from_code(2), "partly")
        self.assertEqual(category_from_code(3), "overcast")
        self.assertEqual(category_from_code(45), "fog")
        self.assertEqual(category_from_code(61), "rain")
        self.assertEqual(category_from_code(71), "snow")
        self.assertEqual(category_from_code(95), "thunder")
        self.assertIsNone(category_from_code(999))
        self.assertIsNone(category_from_code(True))
        self.assertIsNone(category_from_code("61"))


class WeatherCacheTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.cache = self.base / "weather.json"
        manifest_path = write_manifest(
            self.base / "manifest.json",
            {},
            roots=[self.base / "wallpapers"],
            weather=True,
        )
        self.manifest = load_manifest(manifest_path)

    def test_fresh_cache_skips_fetch(self) -> None:
        write_cache(self.cache, "rain", NOW)
        fetch = Mock(side_effect=AssertionError("fetch must not run"))
        self.assertEqual(resolve(self.manifest, self.cache, NOW + timedelta(minutes=1), fetch=fetch), "rain")
        fetch.assert_not_called()

    def test_stale_cache_refetches(self) -> None:
        write_cache(self.cache, "rain", NOW - timedelta(minutes=10))
        category = resolve(self.manifest, self.cache, NOW, fetch=lambda _lat, _lon: "snow")
        self.assertEqual(category, "snow")
        self.assertEqual(read_cache(self.cache).category, "snow")

    def test_failed_fetch_uses_cache(self) -> None:
        write_cache(self.cache, "rain", NOW - timedelta(hours=1))
        category = resolve(
            self.manifest,
            self.cache,
            NOW,
            fetch=Mock(side_effect=RuntimeError("offline")),
        )
        self.assertEqual(category, "rain")

    def test_expired_cache_without_fetch(self) -> None:
        write_cache(self.cache, "rain", NOW - timedelta(hours=7))
        category = resolve(
            self.manifest,
            self.cache,
            NOW,
            fetch=Mock(side_effect=RuntimeError("offline")),
        )
        self.assertIsNone(category)

    def test_offline_uses_cache_only(self) -> None:
        write_cache(self.cache, "rain", NOW - timedelta(hours=1))
        self.assertEqual(resolve(self.manifest, self.cache, NOW, offline=True), "rain")
        write_cache(self.cache, "rain", NOW - timedelta(hours=7))
        self.assertIsNone(resolve(self.manifest, self.cache, NOW, offline=True))

    def test_weather_disabled_ignores_cache(self) -> None:
        disabled_path = write_manifest(
            self.base / "disabled.json",
            {},
            roots=[self.base / "wallpapers"],
            weather=False,
        )
        disabled = load_manifest(disabled_path)
        write_cache(self.cache, "rain", NOW)
        self.assertIsNone(resolve(disabled, self.cache, NOW))

    def test_corrupt_cache_is_ignored(self) -> None:
        self.cache.write_text("{not json", encoding="utf-8")
        self.assertIsNone(read_cache(self.cache))


if __name__ == "__main__":
    unittest.main()
