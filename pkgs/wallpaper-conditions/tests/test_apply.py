from __future__ import annotations

import io
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

from support import touch
from wallpaper_conditions.apply import (
    apply,
    backdrop_command,
    blurred_for,
    crisp_command,
)
from wallpaper_conditions.model import Collection
from wallpaper_conditions.resolve import Match, Resolution

NOW = datetime(2026, 11, 23, 12, 0, tzinfo=timezone.utc)


def make_resolution(files: tuple[Path, ...], *, fallback: bool = False) -> Resolution:
    if fallback:
        return Resolution(
            phase="day",
            weather=None,
            matches=(),
            chosen=None,
            fallback_file=files[0],
            fallback_blurred=Path("/fallback_blurred.jpg"),
        )
    match = Match(collection=Collection("night"), files=files, rank=0, specificity=0)
    return Resolution(
        phase="night",
        weather=None,
        matches=(match,),
        chosen=match,
        fallback_file=Path("/fallback.jpg"),
        fallback_blurred=None,
    )


class CommandTests(unittest.TestCase):
    def test_crisp_command(self) -> None:
        self.assertEqual(
            crisp_command(Path("/wallpapers/night/a.jpg")),
            [
                "awww",
                "img",
                "/wallpapers/night/a.jpg",
                "--transition-type",
                "fade",
                "--transition-duration",
                "2",
            ],
        )

    def test_backdrop_command(self) -> None:
        self.assertEqual(
            backdrop_command(Path("/cache/blur/a.jpg")),
            [
                "awww",
                "img",
                "--namespace",
                "backdrop",
                "/cache/blur/a.jpg",
                "--transition-type",
                "fade",
                "--transition-duration",
                "2",
            ],
        )


class BlurTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.cache = self.base / "cache"
        self.source = touch(self.base / "wallpapers" / "night" / "a.jpg")

    def test_sibling_wins(self) -> None:
        sibling = touch(self.source.with_name("a_blurred.jpg"))
        resolution = make_resolution((self.source,))
        self.assertEqual(blurred_for(resolution, self.source, self.cache), sibling)

    def test_fallback_blurred_wins(self) -> None:
        fallback = touch(self.base / "fallback.jpg")
        blurred = touch(self.base / "fallback_blurred.jpg")
        resolution = Resolution(
            phase="day",
            weather=None,
            matches=(),
            chosen=None,
            fallback_file=fallback,
            fallback_blurred=blurred,
        )
        self.assertEqual(blurred_for(resolution, fallback, self.cache), blurred)

    def test_cache_path_without_generation(self) -> None:
        resolution = make_resolution((self.source,))
        target = blurred_for(resolution, self.source, self.cache, generate=False)
        self.assertIsNotNone(target)
        self.assertEqual(target.parent, self.cache / "blur")
        self.assertEqual(target.suffix, ".jpg")

    def test_dry_run_prints_commands_without_backend(self) -> None:
        resolution = make_resolution((self.source,))
        output = io.StringIO()
        with redirect_stdout(output):
            result = apply(resolution, self.source, self.cache, dry_run=True)
        self.assertFalse(result.applied)
        self.assertIn("awww img", output.getvalue())
        self.assertFalse(self.cache.exists())


if __name__ == "__main__":
    unittest.main()
