from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from support import write_manifest
from wallpaper_conditions.model import ManifestError, load_manifest


class ManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.manifest_path = self.base / "manifest.json"
        self.root = self.base / "wallpapers"

    def test_loads_collections_and_defaults(self) -> None:
        write_manifest(
            self.manifest_path,
            {"night": {"phase": ["night"]}},
            roots=[self.root],
        )
        manifest = load_manifest(self.manifest_path)
        self.assertEqual(manifest.roots, (self.root,))
        self.assertFalse(manifest.weather_enabled)
        self.assertEqual(manifest.order, ("phase", "weather", "season"))
        self.assertEqual(len(manifest.collections), 1)
        self.assertEqual(manifest.collections[0].phase, frozenset({"night"}))
        self.assertEqual(manifest.collections[0].specificity, 1)
        self.assertEqual(manifest.collections[0].priority, 0)

    def test_rejects_relative_root(self) -> None:
        write_manifest(self.manifest_path, {}, roots=[Path("relative")])
        with self.assertRaisesRegex(ManifestError, "absolute"):
            load_manifest(self.manifest_path)

    def test_rejects_unknown_predicate(self) -> None:
        write_manifest(
            self.manifest_path,
            {"night": {"phase": ["night"], "moon": ["full"]}},
            roots=[self.root],
        )
        with self.assertRaisesRegex(ManifestError, "unknown keys"):
            load_manifest(self.manifest_path)

    def test_rejects_unknown_value(self) -> None:
        write_manifest(
            self.manifest_path,
            {"night": {"weather": ["hail"]}},
            roots=[self.root],
        )
        with self.assertRaisesRegex(ManifestError, "unknown values"):
            load_manifest(self.manifest_path)

    def test_rejects_invalid_collection_name(self) -> None:
        write_manifest(
            self.manifest_path,
            {"night sky": {}},
            roots=[self.root],
        )
        with self.assertRaisesRegex(ManifestError, "invalid collection name"):
            load_manifest(self.manifest_path)

    def test_rejects_incomplete_order(self) -> None:
        write_manifest(
            self.manifest_path,
            {},
            roots=[self.root],
            order=["phase"],
        )
        with self.assertRaisesRegex(ManifestError, "permutation"):
            load_manifest(self.manifest_path)

    def test_parses_publish_path(self) -> None:
        publish = self.base / "current.jpg"
        write_manifest(
            self.manifest_path,
            {"night": {"phase": ["night"]}},
            roots=[self.root],
            publish=publish,
        )
        self.assertEqual(load_manifest(self.manifest_path).publish, publish)

    def test_publish_is_optional(self) -> None:
        write_manifest(
            self.manifest_path,
            {"night": {"phase": ["night"]}},
            roots=[self.root],
        )
        self.assertIsNone(load_manifest(self.manifest_path).publish)

    def test_rejects_missing_file(self) -> None:
        with self.assertRaisesRegex(ManifestError, "cannot read manifest"):
            load_manifest(self.base / "absent.json")


if __name__ == "__main__":
    unittest.main()
