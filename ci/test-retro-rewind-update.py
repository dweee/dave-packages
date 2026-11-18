#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("updater", Path(__file__).resolve().parents[1] / "pkgs/retro-rewind-pack/update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.pin = Path(self.directory.name) / "pin.json"
        self.original = {"version": "6.12.8", "hash": "sha256-" + "A" * 43 + "="}
        self.pin.write_text(json.dumps(self.original))
        self.snapshot = {"pointerSource": updater.POINTER, "installUrl": updater.ZIP.format("6.13.5")}

    def test_discover_checks_real_pointer_transport(self):
        with patch.object(updater.subprocess, "check_output", return_value=updater.ZIP.format("6.13.5") + "\r\n") as call:
            found = updater.discover()
        self.assertEqual(found["installUrl"], self.snapshot["installUrl"])
        self.assertEqual(call.call_args.args[0][-1], updater.POINTER)

    def test_update_both_then_safe_noop(self):
        fetched = {"hash": "sha256-" + "B" * 43 + "="}
        with patch.object(updater.subprocess, "check_output", return_value=json.dumps(fetched)) as call:
            report = updater.update(self.pin, self.snapshot, True)
            content = self.pin.read_bytes()
            again = updater.update(self.pin, self.snapshot, True)
        self.assertTrue(report["applied"])
        self.assertEqual(json.loads(content), {"version": "6.13.5", **fetched})
        self.assertFalse(again["changed"])
        self.assertEqual(self.pin.read_bytes(), content)
        call.assert_called_once()

    def test_unexpected_source_and_urls_fail_closed(self):
        for url in ["http://cdn.update.rwfc.net/RetroRewind/zip/6.13.5-full.zip", updater.ZIP.format("../../evil"), self.snapshot["installUrl"] + "?other", "https://evil.test/6.13.5-full.zip", updater.ZIP.format("6.13.5-rc1")]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                updater.update(self.pin, self.snapshot | {"installUrl": url}, True)
        with self.assertRaises(ValueError):
            updater.update(self.pin, self.snapshot | {"pointerSource": "https://evil.test"}, True)

    def test_downgrade_and_preview_do_not_fetch(self):
        with patch.object(updater.subprocess, "check_output") as call:
            self.assertTrue(updater.update(self.pin, self.snapshot)["changed"])
            with self.assertRaises(ValueError):
                updater.update(self.pin, self.snapshot | {"installUrl": updater.ZIP.format("6.1.0")}, True)
        call.assert_not_called()

    def test_fetch_failure_and_invalid_hash_preserve_pin(self):
        before = self.pin.read_bytes()
        with patch.object(updater.subprocess, "check_output", side_effect=subprocess.CalledProcessError(1, "nix")):
            with self.assertRaises(subprocess.CalledProcessError):
                updater.update(self.pin, self.snapshot, True)
        with patch.object(updater.subprocess, "check_output", return_value='{"hash":"unverified"}'):
            with self.assertRaises(ValueError):
                updater.update(self.pin, self.snapshot, True)
        self.assertEqual(self.pin.read_bytes(), before)

    def test_concurrent_manual_pin_edit_is_preserved(self):
        def fetch(*args, **kwargs):
            self.pin.write_text("manual changes\n")
            return json.dumps({"hash": "sha256-" + "B" * 43 + "="})
        with patch.object(updater.subprocess, "check_output", side_effect=fetch):
            with self.assertRaisesRegex(ValueError, "changed during"):
                updater.update(self.pin, self.snapshot, True)
        self.assertEqual(self.pin.read_text(), "manual changes\n")


if __name__ == "__main__":
    unittest.main()
