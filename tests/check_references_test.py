"""Check startup dependencies without relying on a developer's Godot UID cache."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys

CHECKER = Path(__file__).with_name("check_references.py").resolve()


class StartupReferencesTest(unittest.TestCase):
    def check_project(self, config, files=()):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", directory], check=True)
            (root / "project.godot").write_text(config)
            for name in files:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            return subprocess.run(
                [sys.executable, str(CHECKER)], cwd=root,
                capture_output=True, text=True,
            )

    def test_uid_autoload_cannot_depend_on_local_cache(self):
        result = self.check_project('[autoload]\nNetworkTime="*uid://dya78t77yygq6"\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("committed res:// path", result.stdout)

    def test_missing_plugin_is_rejected(self):
        result = self.check_project('[editor_plugins]\nenabled=PackedStringArray("res://addons/netfox/plugin.cfg")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("addons/netfox/plugin.cfg", result.stdout)

    def test_missing_autoload_is_rejected(self):
        result = self.check_project('[autoload]\nService="*res://scripts/service.gd"\n')
        self.assertEqual(result.returncode, 1)

    def test_committed_startup_dependencies_pass(self):
        result = self.check_project(
            '[autoload]\nService="*res://scripts/service.gd"\n'
            '[editor_plugins]\nenabled=PackedStringArray("res://addons/example/plugin.cfg")\n',
            ("scripts/service.gd", "addons/example/plugin.cfg"),
        )
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
