#!/usr/bin/env python3
"""Exercise release identity, atomic update and no-update behavior without Nix writes."""
import base64
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("codexbar_update", Path(__file__).parents[1] / "pkgs/codexbar/update.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def snapshot(version="0.84.0"):
    tag = "v" + version
    assets = [{"name": f"CodexBarCLI-{tag}-linux-{arch}.tar.gz", "id": index + 1,
               "digest": "sha256:" + (str(index + 1) * 64),
               "browser_download_url": f"https://github.com/steipete/CodexBar/releases/download/{tag}/CodexBarCLI-{tag}-linux-{arch}.tar.gz"}
              for index, arch in enumerate(module.ARCHITECTURES.values())]
    return {"repository": module.REPOSITORY, "upstreamRevision": "a" * 40,
            "tagRef": {"ref": "refs/tags/" + tag, "object": {"type": "commit", "sha": "a" * 40}},
            "release": {"tag_name": tag, "draft": False, "prerelease": False, "assets": assets}}


class Updates(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.pin = Path(self.directory.name) / "pin.json"
        self.pin.write_text(json.dumps(module.candidate(snapshot("0.83.0"))[0]))

    def fetched(self, command, **kwargs):
        url = command[-1]
        asset = next(a for a in snapshot()["release"]["assets"] if a["browser_download_url"] == url)
        sri = "sha256-" + base64.b64encode(bytes.fromhex(asset["digest"].split(":")[1])).decode()
        return subprocess.CompletedProcess(command, 0, json.dumps({"hash": sri, "storePath": "/nix/store/synthetic-unit-fixture"}))

    def test_both_architectures_update_before_noop(self):
        with patch.object(module.subprocess, "run", side_effect=self.fetched) as fetch:
            report = module.update(self.pin, snapshot(), apply=True)
        self.assertTrue(report["applied"])
        self.assertEqual(fetch.call_count, 2)
        self.assertEqual(set(json.loads(self.pin.read_text())["assets"]), set(module.ARCHITECTURES))
        before = self.pin.read_bytes()
        with patch.object(module.subprocess, "run") as fetch:
            report = module.update(self.pin, snapshot(), apply=True)
        fetch.assert_not_called()
        self.assertFalse(report["changed"])
        self.assertEqual(self.pin.read_bytes(), before)

    def test_second_asset_failure_preserves_every_original_byte(self):
        before = self.pin.read_bytes()
        with patch.object(module.subprocess, "run", side_effect=[self.fetched(["url", snapshot()["release"]["assets"][0]["browser_download_url"]]), subprocess.CalledProcessError(1, ["nix"])]):
            with self.assertRaises(subprocess.CalledProcessError):
                module.update(self.pin, snapshot(), apply=True)
        self.assertEqual(self.pin.read_bytes(), before)

    def test_hash_mismatch_preserves_pin(self):
        before = self.pin.read_bytes()
        with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, '{"hash":"sha256-wrong","storePath":"/synthetic"}')):
            with self.assertRaises(ValueError):
                module.update(self.pin, snapshot(), apply=True)
        self.assertEqual(self.pin.read_bytes(), before)

    def test_bad_release_identity_and_incomplete_platforms_fail(self):
        for mutation in [lambda s: s.update(upstreamRevision="b" * 40), lambda s: s["release"].update(prerelease=True), lambda s: s["release"]["assets"].pop(), lambda s: s["release"]["assets"][0].update(browser_download_url="https://example.test/asset")]:
            data = snapshot()
            mutation(data)
            with self.assertRaises(ValueError):
                module.candidate(data)

    def test_changed_same_version_is_not_silently_replaced(self):
        original = snapshot("0.83.0")
        original["release"]["assets"][0]["digest"] = "sha256:" + "f" * 64
        before = self.pin.read_bytes()
        with self.assertRaises(ValueError), patch.object(module.subprocess, "run") as fetch:
            module.update(self.pin, original, apply=True)
        fetch.assert_not_called()
        self.assertEqual(self.pin.read_bytes(), before)

    def test_concurrent_manual_edit_survives(self):
        manual = '{"manual":true}\n'
        def fetch(command, **kwargs):
            self.pin.write_text(manual)
            return self.fetched(command, **kwargs)
        with patch.object(module.subprocess, "run", side_effect=fetch), self.assertRaises(ValueError):
            module.update(self.pin, snapshot(), apply=True)
        self.assertEqual(self.pin.read_text(), manual)


if __name__ == "__main__":
    unittest.main()
