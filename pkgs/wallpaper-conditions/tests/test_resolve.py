from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from support import touch, write_manifest
from wallpaper_conditions.library import scan
from wallpaper_conditions.model import load_manifest
from wallpaper_conditions.resolve import resolve

COLLECTIONS = {
    "night": {"phase": ["night"]},
    "rain": {"weather": ["rain"]},
    "rain-night": {"phase": ["night"], "weather": ["rain"]},
}


def scan_theme(manifest):
    return scan(manifest.theme(manifest.default_theme))


def resolve_theme(manifest, library, *, phase, weather):
    return resolve(
        manifest.theme(manifest.default_theme),
        library,
        phase=phase,
        weather=weather,
        order=manifest.order,
        fallback_file=manifest.fallback_file,
        fallback_blurred=manifest.fallback_blurred,
    )


class ResolveTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "wallpapers"
        for folder in ("night", "rain", "rain-night"):
            touch(self.root / folder / "one.jpg")
        self.fallback = touch(self.base / "fallback.jpg")
        self.manifest_path = write_manifest(
            self.base / "manifest.json",
            COLLECTIONS,
            roots=[self.root],
            fallback_file=self.fallback,
        )
        self.manifest = load_manifest(self.manifest_path)
        self.library = scan_theme(self.manifest)

    def test_most_specific_collection_wins(self) -> None:
        resolution = resolve_theme(
            self.manifest,
            self.library,
            phase="night",
            weather="rain",
        )
        self.assertEqual(resolution.collection_name, "rain-night")
        self.assertEqual(resolution.chosen.specificity, 2)

    def test_order_breaks_single_predicate_ties(self) -> None:
        manifest_path = write_manifest(
            self.base / "tie.json",
            {"night": {"phase": ["night"]}, "rain": {"weather": ["rain"]}},
            roots=[self.root],
            fallback_file=self.fallback,
            order=["phase", "weather"],
        )
        resolution = resolve_theme(
            load_manifest(manifest_path),
            self.library,
            phase="night",
            weather="rain",
        )
        self.assertEqual(resolution.collection_name, "night")

        manifest_path = write_manifest(
            self.base / "tie-weather.json",
            {"night": {"phase": ["night"]}, "rain": {"weather": ["rain"]}},
            roots=[self.root],
            fallback_file=self.fallback,
            order=["weather", "phase"],
        )
        resolution = resolve_theme(
            load_manifest(manifest_path),
            self.library,
            phase="night",
            weather="rain",
        )
        self.assertEqual(resolution.collection_name, "rain")

    def test_empty_collection_is_skipped(self) -> None:
        manifest_path = write_manifest(
            self.base / "empty-specific.json",
            {
                "night-rain": {"phase": ["night"], "weather": ["rain"]},
                "night": {"phase": ["night"]},
            },
            roots=[self.root],
            fallback_file=self.fallback,
        )
        manifest = load_manifest(manifest_path)
        resolution = resolve_theme(
            manifest,
            scan_theme(manifest),
            phase="night",
            weather="rain",
        )
        self.assertEqual(resolution.collection_name, "night")

    def test_unknown_weather_only_matches_phase(self) -> None:
        resolution = resolve_theme(
            self.manifest,
            self.library,
            phase="night",
            weather=None,
        )
        self.assertEqual(resolution.collection_name, "night")
        self.assertNotIn("rain-night", [match.collection.name for match in resolution.matches])

    def test_priority_breaks_same_specificity_ties(self) -> None:
        touch(self.root / "rain-low" / "one.jpg")
        touch(self.root / "rain-high" / "one.jpg")
        manifest_path = write_manifest(
            self.base / "priority.json",
            {
                "rain-low": {"weather": ["rain"]},
                "rain-high": {"weather": ["rain"], "priority": 1},
            },
            roots=[self.root],
            fallback_file=self.fallback,
        )
        manifest = load_manifest(manifest_path)
        resolution = resolve_theme(
            manifest,
            scan_theme(manifest),
            phase="day",
            weather="rain",
        )
        self.assertEqual(resolution.collection_name, "rain-high")
        self.assertEqual(resolution.matches[0].priority, 1)

    def test_no_match_uses_nix_fallback(self) -> None:
        manifest_path = write_manifest(
            self.base / "snow-only.json",
            {"snow": {"weather": ["snow"]}},
            roots=[self.root],
            fallback_file=self.fallback,
        )
        manifest = load_manifest(manifest_path)
        resolution = resolve_theme(manifest, scan_theme(manifest), phase="day", weather=None)
        self.assertIsNone(resolution.chosen)
        self.assertEqual(resolution.files, (self.fallback,))
        self.assertEqual(resolution.blurred, self.base / "fallback_blurred.jpg")


if __name__ == "__main__":
    unittest.main()
