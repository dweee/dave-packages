#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("boundary", ROOT / "ci/check-public-source.py")
boundary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(boundary)


class PublicSourceBoundary(unittest.TestCase):
    def test_current_first_party_exports_are_portable(self):
        self.assertEqual(boundary.check(ROOT), [])

    def test_private_operational_docs_are_rejected(self):
        for content, rule in [
            ("Configuration: machines/example-server/default.nix", "operator-path"),
            ("Saved under /persist/backups/example", "operator-path"),
            ("Private audit and consolidated-handoff results", "private-report"),
            ("Runtime secret: example-secret.age", "encrypted-secret"),
        ]:
            with self.subTest(rule=rule):
                self.assertIn(rule, boundary.inspect(Path("pkgs/example/README.md"), content))

    def test_public_package_instructions_remain_allowed(self):
        self.assertEqual(boundary.inspect(Path("pkgs/example/README.md"),
            "Build with nix build .#example. Configure runtime credentials separately."), [])

    def test_vendored_upstream_and_fixture_data_are_outside_this_check(self):
        self.assertFalse(boundary.included(Path("pkgs/wiicompiled/source/runtime/README.md")))
        self.assertFalse(boundary.included(Path("ci/test-public-source.py")))
        self.assertTrue(boundary.included(Path("pkgs/example/README.md")))
        self.assertTrue(boundary.included(Path("nix/platforms.json")))


if __name__ == "__main__":
    unittest.main()
