"""Exercise vendor merge preservation and failure behavior using a local upstream."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("redlib_updater", Path(__file__).parents[1] / "update-redlib-vendor.py")
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


class RedlibCandidates(unittest.TestCase):
    def test_preservation_and_conflicts(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            upstream = directory / "upstream"
            upstream.mkdir()

            def git(*arguments):
                return subprocess.check_output(
                    ["git", "-c", "user.name=Test", "-c", "user.email=test@localhost", *arguments],
                    cwd=upstream, text=True).strip()

            git("init", "-q")
            (upstream / "custom.txt").write_text("base\n")
            (upstream / "upstream.txt").write_text("old\n")
            (upstream / "deleted.txt").write_text("delete locally\n")
            git("add", ".")
            git("commit", "-qm", "base")
            base = git("rev-parse", "HEAD")
            root = directory / "root"
            vendor = root / "vendor/redlib"
            vendor.mkdir(parents=True)
            (vendor / "custom.txt").write_text("named feeds custom\n")
            (vendor / "upstream.txt").write_text("old\n")
            (vendor / "VENDOR.md").write_text(f"Base commit: `{base}`\n")
            package = root / "pkgs/redlib"
            package.mkdir(parents=True)
            (package / "default.nix").write_text('{ }: { src = ../../vendor/redlib; cargoHash = "old"; }')
            (upstream / "upstream.txt").write_text("new\n")
            git("add", ".")
            git("commit", "-qm", "upstream improvement")
            with patch.object(updater, "UPSTREAM", str(upstream)), contextlib.redirect_stdout(io.StringIO()):
                destination = directory / "candidate"
                with patch.object(sys, "argv", ["test", "--root", str(root), "--candidate", str(destination)]):
                    self.assertEqual(updater.main(), 0)
                source = destination / "source"
                self.assertEqual((source / "custom.txt").read_text(), "named feeds custom\n")
                self.assertEqual((source / "upstream.txt").read_text(), "new\n")
                self.assertFalse((source / "deleted.txt").exists())
                self.assertEqual((vendor / "upstream.txt").read_text(), "old\n")
                (upstream / "custom.txt").write_text("conflicting upstream\n")
                git("add", ".")
                git("commit", "-qm", "conflict")
                with patch.object(sys, "argv", ["test", "--root", str(root), "--candidate", str(directory / "conflict")]):
                    self.assertEqual(updater.main(), 1)
                self.assertEqual((vendor / "custom.txt").read_text(), "named feeds custom\n")
                with patch.object(sys, "argv", ["test", "--root", str(root), "--candidate", str(destination)]):
                    with self.assertRaisesRegex(RuntimeError, "already exists"):
                        updater.main()


if __name__ == "__main__":
    unittest.main()
