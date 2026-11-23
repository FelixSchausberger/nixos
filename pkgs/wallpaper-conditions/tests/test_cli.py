from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from support import touch, write_manifest
from wallpaper_conditions.cli import main

NIGHT = "2026-12-21T23:00:00+01:00"
DAY = "2026-12-21T12:00:00+01:00"


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
        output = io.StringIO()
        with redirect_stdout(output):
            code = main(
                [
                    "--manifest",
                    str(self.manifest),
                    "--cache-dir",
                    str(self.cache),
                    *args,
                ]
            )
        self.assertEqual(code, 0)
        return output.getvalue()

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

    def test_version(self) -> None:
        self.assertEqual(self.run_cli("version").strip(), "0.1.0")


if __name__ == "__main__":
    unittest.main()
