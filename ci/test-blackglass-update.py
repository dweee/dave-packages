#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("updater", Path(__file__).resolve().parents[1] / "pkgs/blackglass/update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class Updates(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.pin = Path(self.temporary.name) / "pin.json"
        self.pin.write_text(json.dumps({"revision": "a" * 40, "version": "0-unstable-2024-01-01", "hash": "sha256-" + "A" * 43 + "="}))
        self.snapshot = {"repository": updater.REPOSITORY, "branch": "master", "revision": "b" * 40}
        self.fetched = {"url": updater.REPOSITORY, "rev": "b" * 40,
                        "date": "2026-10-09T11:42:44+11:00", "hash": "sha256-" + "B" * 43 + "=",
                        "fetchLFS": False, "fetchSubmodules": False, "deepClone": False, "leaveDotGit": False}

    def test_live_ref_resolution_and_changed_default_branch(self):
        refs = "ref: refs/heads/master\tHEAD\n" + "b" * 40 + "\tHEAD\n" + "b" * 40 + "\trefs/heads/master\n"
        with patch.object(updater.subprocess, "check_output", return_value=refs):
            self.assertEqual(updater.discover(), self.snapshot)
        with patch.object(updater.subprocess, "check_output", return_value=refs.replace("heads/master", "heads/main")), self.assertRaises(ValueError):
            updater.discover()

    def test_exact_prefetch_update_then_byte_identical_noop(self):
        with patch.object(updater.subprocess, "check_output", return_value=json.dumps(self.fetched)) as call:
            report = updater.update(self.pin, self.snapshot, True)
            before = self.pin.read_bytes()
            again = updater.update(self.pin, self.snapshot, True)
        self.assertTrue(report["applied"])
        self.assertEqual(report["newVersion"], "0-unstable-2026-10-09")
        self.assertFalse(again["changed"])
        self.assertEqual(before, self.pin.read_bytes())
        call.assert_called_once()

    def test_unapproved_policy_and_revision_rejected(self):
        for change in [{"repository": "https://evil.test"}, {"branch": "main"}, {"revision": "master"}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                updater.update(self.pin, self.snapshot | change, True)

    def test_prefetch_identity_semantics_and_hash_must_match(self):
        before = self.pin.read_bytes()
        for change in [{"rev": "c" * 40}, {"url": "https://evil.test"}, {"fetchSubmodules": True}, {"leaveDotGit": True}, {"hash": "unverified"}, {"date": "2020-01-01T00:00:00+00:00"}]:
            with self.subTest(change=change), patch.object(updater.subprocess, "check_output", return_value=json.dumps(self.fetched | change)), self.assertRaises(ValueError):
                updater.update(self.pin, self.snapshot, True)
        self.assertEqual(before, self.pin.read_bytes())

    def test_fetch_failure_and_preview_preserve_pin(self):
        before = self.pin.read_bytes()
        with patch.object(updater.subprocess, "check_output", side_effect=subprocess.CalledProcessError(1, "fetch")):
            with self.assertRaises(subprocess.CalledProcessError):
                updater.update(self.pin, self.snapshot, True)
            self.assertTrue(updater.update(self.pin, self.snapshot)["changed"])
        self.assertEqual(before, self.pin.read_bytes())

    def test_manual_concurrent_pin_is_preserved(self):
        def fetched(*args, **kwargs):
            self.pin.write_text("manual edit\n")
            return json.dumps(self.fetched)
        with patch.object(updater.subprocess, "check_output", side_effect=fetched), self.assertRaisesRegex(ValueError, "changed during"):
            updater.update(self.pin, self.snapshot, True)
        self.assertEqual(self.pin.read_text(), "manual edit\n")


if __name__ == "__main__":
    unittest.main()
