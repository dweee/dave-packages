#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("updater", Path(__file__).resolve().parents[1] / "pkgs/yaas/update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.folder = self.root / "pkgs/yaas"
        self.folder.mkdir(parents=True)
        self.recipe = self.folder / "default.nix"
        self.lock = self.folder / "pubspec.lock.json"
        self.recipe.write_text('version = "0-unstable-2026-09-17"; rev = "' + 'a' * 40 + '";')
        self.lock.write_text('{"packages": {"old": {}}}\n')
        self.snapshot = {"repository": updater.REPOSITORY, "branch": "master", "commit": {
            "sha": "b" * 40, "commit": {"committer": {"date": "2026-10-29T14:07:22Z"}}}}

    def updated_recipe(self, *args, **kwargs):
        self.recipe.write_text('version = "0-unstable-2026-10-29"; rev = "' + 'b' * 40 + '";')

    def generated(self, argv, **kwargs):
        if argv[0] == "nix":
            return json.dumps([{"outputs": {"out": "/nix/store/test-source"}}])
        self.assertEqual(argv[:3], ["yq", "-o=json", "."])
        return json.dumps({"packages": {"new": {}}})

    def test_frozen_source_cargo_and_flutter_then_noop(self):
        with patch.object(updater.subprocess, "run", side_effect=self.updated_recipe) as run, patch.object(updater.subprocess, "check_output", side_effect=self.generated):
            result = updater.update(self.root, self.snapshot, True)
            contents = self.recipe.read_bytes(), self.lock.read_bytes()
            again = updater.update(self.root, self.snapshot, True)
        self.assertTrue(result["applied"])
        self.assertTrue(result["flutterLockChanged"])
        self.assertFalse(again["changed"])
        self.assertEqual(contents, (self.recipe.read_bytes(), self.lock.read_bytes()))
        run.assert_called_once()
        self.assertIn("--version=branch=" + "b" * 40, run.call_args.args[0])
        self.assertIn("--version-regex=^(0-unstable-[0-9-]+)$", run.call_args.args[0])

    def test_unapproved_policy_and_bad_identity_fail(self):
        for changed in [{"repository": "other/yaas"}, {"branch": "nightly"}, {"commit": {"sha": "main"}}]:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                updater.update(self.root, self.snapshot | changed, True)

    def test_preview_has_no_tool_or_source_writes(self):
        contents = self.recipe.read_bytes(), self.lock.read_bytes()
        with patch.object(updater.subprocess, "run") as run, patch.object(updater.subprocess, "check_output") as output:
            self.assertTrue(updater.update(self.root, self.snapshot)["changed"])
        run.assert_not_called()
        output.assert_not_called()
        self.assertEqual(contents, (self.recipe.read_bytes(), self.lock.read_bytes()))

    def test_downgrade_and_changed_version_policy_require_review(self):
        for version in ["0-unstable-2026-11-11", "1.0.0"]:
            self.recipe.write_text('version = "' + version + '"; rev = "' + 'a' * 40 + '";')
            with self.subTest(version=version), self.assertRaises(ValueError):
                updater.update(self.root, self.snapshot, True)

    def test_wrong_source_result_stops_before_flutter_write(self):
        before = self.lock.read_bytes()
        with patch.object(updater.subprocess, "run"), self.assertRaisesRegex(ValueError, "frozen upstream"):
            updater.update(self.root, self.snapshot, True)
        self.assertEqual(self.lock.read_bytes(), before)

    def test_concurrent_flutter_edit_survives(self):
        def generate(argv, **kwargs):
            value = self.generated(argv, **kwargs)
            if argv[0] == "yq":
                self.lock.write_text("manual lock change\n")
            return value
        with patch.object(updater.subprocess, "run", side_effect=self.updated_recipe), patch.object(updater.subprocess, "check_output", side_effect=generate), self.assertRaisesRegex(ValueError, "changed during"):
            updater.update(self.root, self.snapshot, True)
        self.assertEqual(self.lock.read_text(), "manual lock change\n")


if __name__ == "__main__":
    unittest.main()
