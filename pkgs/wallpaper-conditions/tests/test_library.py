from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from support import touch, write_manifest
from wallpaper_conditions.library import scan
from wallpaper_conditions.model import load_manifest


class LibraryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "wallpapers"
        self.manifest_path = write_manifest(
            self.base / "manifest.json",
            {
                "night": {"phase": ["night"]},
                "rain": {"weather": ["rain"]},
                "empty": {},
            },
            roots=[self.root],
        )
        self.manifest = load_manifest(self.manifest_path)

        touch(self.root / "night" / "a.jpg")
        touch(self.root / "night" / "b.PNG")
        touch(self.root / "night" / "c.txt")
        touch(self.root / "night" / ".hidden.jpg")
        touch(self.root / "night" / "a_blurred.jpg")
        touch(self.root / "night" / "NESTED_BLURRED.JPG")
        touch(self.root / "night" / "nested" / "d.jpg")
        touch(self.root / "unknown" / "x.jpg")

    def test_filters_images_and_blurred_variants(self) -> None:
        library = scan(self.manifest)
        names = [path.name for path in library.get("night")]
        self.assertEqual(names, ["a.jpg", "b.PNG"])

    def test_reports_unknown_directories(self) -> None:
        library = scan(self.manifest)
        self.assertEqual([path.name for path in library.unknown_dirs], ["unknown"])

    def test_empty_collection_has_no_files(self) -> None:
        library = scan(self.manifest)
        self.assertEqual(library.get("empty"), ())

    def test_missing_root(self) -> None:
        manifest_path = write_manifest(
            self.base / "missing.json",
            {"night": {"phase": ["night"]}},
            roots=[self.base / "absent"],
        )
        library = scan(load_manifest(manifest_path))
        self.assertEqual(library.missing_roots, (self.base / "absent",))

    def test_multiple_roots_merge_and_deduplicate(self) -> None:
        second = self.base / "second"
        touch(second / "night" / "other.jpg")
        manifest_path = write_manifest(
            self.base / "multi.json",
            {"night": {"phase": ["night"]}},
            roots=[self.root, second, self.root],
        )
        library = scan(load_manifest(manifest_path))
        names = sorted(path.name for path in library.get("night"))
        self.assertEqual(names, ["a.jpg", "b.PNG", "other.jpg"])


if __name__ == "__main__":
    unittest.main()
