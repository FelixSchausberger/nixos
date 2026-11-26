from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from typing import Callable
from unittest.mock import patch

from support import touch, write_manifest
from wallpaper_conditions.apply import ApplyResult
from wallpaper_conditions.cli import main

NIGHT = "2026-12-21T23:00:00+01:00"
DAY = "2026-12-21T12:00:00+01:00"


def fake_publish(calls: list[Path]) -> Callable[[Path, Path], bool]:
    """Record each published source and write a JPEG marker to the target."""

    def publish(source: Path, target: Path) -> bool:
        target.write_bytes(b"\xff\xd8\xff")
        calls.append(source)
        return True

    return publish


class CliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "wallpapers"
        self.cache = self.base / "cache"
        self.publish = self.base / "current.jpg"
        self.fallback = touch(self.base / "fallback.jpg")
        self.fallback_blurred = touch(self.base / "fallback_blurred.jpg")
        touch(self.root / "night" / "one.jpg")
        touch(self.root / "nature" / "one.jpg")
        touch(self.root / "unknown" / "x.jpg")
        self.manifest = write_manifest(
            self.base / "manifest.json",
            {
                "night": {"phase": ["night"]},
                "nature": {},
            },
            roots=[self.root],
            fallback_file=self.fallback,
            fallback_blurred=self.fallback_blurred,
            publish=self.publish,
        )

    def run_cli(self, *args: str) -> str:
        return self.run_with(self.manifest, *args)

    def run_with(self, manifest: Path, *args: str) -> str:
        output = io.StringIO()
        with redirect_stdout(output):
            code = main(
                [
                    "--manifest",
                    str(manifest),
                    "--cache-dir",
                    str(self.cache),
                    *args,
                ]
            )
        self.assertEqual(code, 0)
        return output.getvalue()

    def themed_manifest(self) -> Path:
        root = self.base / "themed"
        touch(root / "landscapes" / "night" / "one.jpg")
        touch(root / "plants" / "any" / "leaf.jpg")
        return write_manifest(
            self.base / "themed.json",
            {},
            roots=[root],
            themes={
                "landscapes": {"collections": {"night": {"phase": ["night"]}}},
                "plants": {"collections": {"any": {}}},
            },
            default_theme="landscapes",
            active_theme_file=self.base / "active-theme",
            publish=self.base / "themed-current.jpg",
            fallback_file=self.fallback,
            fallback_blurred=self.fallback_blurred,
        )

    def test_status_json_selects_the_specific_folder(self) -> None:
        payload = json.loads(self.run_cli("--now", NIGHT, "status", "--offline", "--json"))
        self.assertEqual(payload["phase"], "night")
        self.assertEqual(payload["collection"], "night")
        self.assertTrue(payload["file"].endswith("night/one.jpg"))
        self.assertEqual(payload["matches"][0]["name"], "night")
        self.assertFalse((self.cache / "state.json").exists())

    def test_status_day_uses_the_unconstrained_folder(self) -> None:
        payload = json.loads(self.run_cli("--now", DAY, "status", "--offline", "--json"))
        self.assertEqual(payload["phase"], "day")
        self.assertEqual(payload["collection"], "nature")

    def test_status_without_a_match_uses_the_nix_fallback(self) -> None:
        manifest = write_manifest(
            self.base / "night-only.json",
            {"night": {"phase": ["night"]}},
            roots=[self.root],
            fallback_file=self.fallback,
            fallback_blurred=self.fallback_blurred,
            publish=self.publish,
        )
        output = io.StringIO()
        with redirect_stdout(output):
            code = main(
                [
                    "--manifest",
                    str(manifest),
                    "--cache-dir",
                    str(self.cache),
                    "--now",
                    DAY,
                    "status",
                    "--offline",
                    "--json",
                ]
            )
        self.assertEqual(code, 0)
        payload = json.loads(output.getvalue())
        self.assertIsNone(payload["collection"])
        self.assertEqual(payload["file"], str(self.fallback))

    def test_doctor_reports_counts_and_unknown_folders(self) -> None:
        output = self.run_cli("doctor")
        self.assertIn("collection night: 1 images", output)
        self.assertIn("undeclared folder (ignored)", output)
        self.assertIn("backend:", output)

    def test_apply_dry_run_does_not_write_state(self) -> None:
        output = self.run_cli("--now", NIGHT, "apply", "--dry-run")
        self.assertIn("awww img", output)
        self.assertFalse((self.cache / "state.json").exists())
        self.assertFalse(self.publish.exists())

    def test_apply_publishes_without_a_display_backend(self) -> None:
        calls: list[Path] = []
        with (
            patch(
                "wallpaper_conditions.cli.apply",
                return_value=ApplyResult(False, "no awww daemon"),
            ),
            patch("wallpaper_conditions.cli.publish_current", side_effect=fake_publish(calls)),
        ):
            self.run_cli("--now", NIGHT, "apply")

        chosen = str(self.root / "night" / "one.jpg")
        self.assertEqual(calls, [Path(chosen)])
        state = json.loads((self.cache / "state.json").read_text())
        self.assertEqual(state["selected_file"], chosen)
        self.assertEqual(state["published_file"], chosen)
        self.assertIsNone(state["applied_file"])
        self.assertEqual(self.publish.read_bytes(), b"\xff\xd8\xff")

    def test_apply_skips_an_unchanged_published_file(self) -> None:
        calls: list[Path] = []
        with (
            patch(
                "wallpaper_conditions.cli.apply",
                return_value=ApplyResult(True, "applied"),
            ),
            patch("wallpaper_conditions.cli.publish_current", side_effect=fake_publish(calls)),
        ):
            self.run_cli("--now", NIGHT, "apply")
            self.run_cli("--now", NIGHT, "apply")

        self.assertEqual(len(calls), 1)

    def test_apply_republishes_a_missing_file(self) -> None:
        calls: list[Path] = []
        with (
            patch(
                "wallpaper_conditions.cli.apply",
                return_value=ApplyResult(True, "applied"),
            ),
            patch("wallpaper_conditions.cli.publish_current", side_effect=fake_publish(calls)),
        ):
            self.run_cli("--now", NIGHT, "apply")
            self.publish.unlink()
            self.run_cli("--now", NIGHT, "apply")

        self.assertEqual(len(calls), 2)

    def test_version(self) -> None:
        self.assertEqual(self.run_cli("version").strip(), "0.1.0")

    def test_status_reports_the_theme_and_the_shared_file(self) -> None:
        manifest = self.themed_manifest()
        payload = json.loads(
            self.run_with(manifest, "--now", NIGHT, "status", "--offline", "--json")
        )
        self.assertEqual(payload["theme"], "landscapes")
        self.assertEqual(payload["themes"], ["landscapes", "plants"])
        self.assertTrue(payload["active_theme_file"].endswith("active-theme"))

    def test_theme_switch_writes_the_shared_file(self) -> None:
        manifest = self.themed_manifest()
        with (
            patch(
                "wallpaper_conditions.cli.apply",
                return_value=ApplyResult(False, "no awww daemon"),
            ),
            patch("wallpaper_conditions.cli.publish_current", return_value=True),
        ):
            self.run_with(manifest, "--now", NIGHT, "theme", "plants")

        self.assertEqual((self.base / "active-theme").read_text().strip(), "plants")
        state = json.loads((self.cache / "state.json").read_text())
        self.assertEqual(state["theme"], "plants")
        self.assertIn("plants/any/leaf.jpg", state["selected_file"])

    def test_shared_file_drives_the_selection(self) -> None:
        manifest = self.themed_manifest()
        (self.base / "active-theme").write_text("plants\n", encoding="utf-8")
        payload = json.loads(
            self.run_with(manifest, "--now", NIGHT, "status", "--offline", "--json")
        )
        self.assertEqual(payload["theme"], "plants")
        self.assertIn("plants/any/leaf.jpg", payload["file"])


if __name__ == "__main__":
    unittest.main()
