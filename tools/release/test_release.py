"""Exercise the complete package -> stage -> promote path with small fixtures."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from package_windows import package

spec = importlib.util.spec_from_file_location("publisher", Path(__file__).resolve().parents[2] / "deploy/publish_windows.py")
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class ReleaseTests(unittest.TestCase):
    platform = "windows"
    executable = "Starfall.exe"
    archive_name = "Starfall-Windows.zip"
    launcher_name = "StarfallLauncher.exe"
    library = "support.dll"
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.export = self.base / "export"
        self.export.mkdir()
        self.launcher = self.base / "launcher.exe"
        self.launcher.write_bytes(b"launcher fixture")
        self.root = self.base / "downloads"

    def make(self, letter):
        for name in (self.executable, "Starfall.pck", self.library):
            (self.export / name).write_bytes((name + letter).encode())
        # Source and tooling must not accidentally be shipped alongside exports.
        (self.export / "secret.env").write_text("fixture not for publication")
        out = self.base / letter
        m = package(self.export, self.launcher, out, letter * 40, "0.11.0", self.platform)
        return out, m["server_tag"]

    def test_stage_is_not_publication_and_rollback_pairs_feed(self):
        first, tag1 = self.make("a")
        publisher.stage(first, self.root, tag1, self.platform)
        self.assertFalse((self.root / "manifest.json").exists())
        self.assertFalse((self.root / "releases" / tag1 / "secret.env").exists())
        publisher.promote(self.root, tag1, self.platform)
        old = (self.root / "manifest.json").read_bytes()
        second, tag2 = self.make("b")
        publisher.stage(second, self.root, tag2, self.platform)
        self.assertEqual(old, (self.root / "manifest.json").read_bytes())
        publisher.promote(self.root, tag2, self.platform)
        self.assertEqual(json.loads((self.root / "manifest.json").read_text())["server_tag"], tag2)
        publisher.promote(self.root, tag1, self.platform)
        self.assertEqual(old, (self.root / "manifest.json").read_bytes())

    def test_corrupt_transfer_is_not_staged(self):
        source, tag = self.make("a")
        with (source / self.archive_name).open("ab") as f:
            f.write(b"broken")
        with self.assertRaises(ValueError):
            publisher.stage(source, self.root, tag, self.platform)
        self.assertFalse((self.root / "releases" / tag).exists())

    def test_invalid_launcher_does_not_replace_feed(self):
        source, tag = self.make("a")
        publisher.stage(source, self.root, tag, self.platform)
        publisher.promote(self.root, tag, self.platform)
        old = (self.root / "manifest.json").read_bytes()
        (self.root / "releases" / tag / self.launcher_name).write_bytes(b"broken")
        with self.assertRaises(ValueError):
            publisher.promote(self.root, tag, self.platform)
        self.assertEqual(old, (self.root / "manifest.json").read_bytes())

    def test_missing_or_mismatched_client_cannot_be_promoted(self):
        source, tag = self.make("a")
        with self.assertRaises(ValueError):
            publisher.stage(source, self.root, "sha-bbbbbbb", self.platform)
        with self.assertRaises(FileNotFoundError):
            publisher.promote(self.root, tag, self.platform)
        with self.assertRaises(ValueError):
            publisher.verify(source, "../escape", self.platform)

    def test_rerun_does_not_replace_immutable_release(self):
        source, tag = self.make("a")
        publisher.stage(source, self.root, tag, self.platform)
        first = (self.root / "releases" / tag / self.archive_name).read_bytes()
        # Same commit rerun with a different launcher is intentionally reused.
        self.launcher.write_bytes(b"rebuilt launcher")
        package(self.export, self.launcher, source, "a" * 40, "0.11.0", self.platform)
        publisher.stage(source, self.root, tag, self.platform)
        self.assertEqual(first, (self.root / "releases" / tag / self.archive_name).read_bytes())
        self.assertEqual((self.root / "releases" / tag / self.launcher_name).read_bytes(), b"launcher fixture")

    def test_short_tag_collision_does_not_replace_release(self):
        source, tag = self.make("a")
        publisher.stage(source, self.root, tag, self.platform)
        package(self.export, self.launcher, source, "a" * 7 + "b" * 33, "0.11.0", self.platform)
        with self.assertRaises(ValueError):
            publisher.stage(source, self.root, tag, self.platform)

    def test_missing_export_fails(self):
        with self.assertRaises(ValueError):
            package(self.export, self.launcher, self.base / "out", "a" * 40, "0.11.0", self.platform)


class LinuxReleaseTests(ReleaseTests):
    platform = "linux"
    executable = "Starfall.x86_64"
    archive_name = "Starfall-Linux.zip"
    launcher_name = "StarfallLauncher"
    library = "support.so"

    def test_platforms_cannot_be_confused(self):
        source, tag = self.make("a")
        self.assertIn("/downloads/linux/releases/", json.loads((source / "manifest.json").read_text())["url"])
        with self.assertRaises(ValueError):
            publisher.verify(source, tag, "windows")


if __name__ == "__main__":
    unittest.main()
