#!/usr/bin/env python3
"""Exercise release identity, atomic update and no-update behavior without Nix writes."""
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

SOURCE = "sha256-" + "S" * 43 + "="
DEPS = "sha256-" + "D" * 43 + "="


def snapshot(version="0.84.0", revision="a" * 40):
    tag = "v" + version
    return {"repository": module.REPOSITORY, "upstreamRevision": revision,
            "tagRef": {"ref": "refs/tags/" + tag, "object": {"type": "commit", "sha": revision}},
            "release": {"tag_name": tag, "draft": False, "prerelease": False, "assets": []}}


def nix(command, **kwargs):
    if command[:3] == ["nix", "flake", "prefetch"]:
        revision = command[-1].rsplit("/", 1)[1]
        return subprocess.CompletedProcess(command, 0, json.dumps({"hash": SOURCE, "locked": {"rev": revision}}), "")
    if command[:2] == ["nix", "build"]:
        assert command[command.index("narHash") + 1] == SOURCE
        return subprocess.CompletedProcess(command, 1, "", f"hash mismatch\n  specified: sha256-AAAA\n     got:    {DEPS}\n")
    raise AssertionError(command)


class Updates(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.pin = Path(self.directory.name) / "pin.json"
        self.pin.write_text(json.dumps({"version": "0.83.0", "revision": "b" * 40,
                                        "hash": SOURCE, "swiftpmDepsHash": DEPS}))

    def test_source_and_dependency_hashes_update_before_noop(self):
        with patch.object(module.subprocess, "run", side_effect=nix) as run:
            report = module.update(self.pin, snapshot(), apply=True)
        self.assertTrue(report["applied"])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(json.loads(self.pin.read_text()), {"version": "0.84.0", "revision": "a" * 40,
                                                             "hash": SOURCE, "swiftpmDepsHash": DEPS})
        before = self.pin.read_bytes()
        with patch.object(module.subprocess, "run") as run:
            report = module.update(self.pin, snapshot(), apply=True)
        run.assert_not_called()
        self.assertFalse(report["changed"])
        self.assertEqual(self.pin.read_bytes(), before)

    def test_dependency_hash_failure_preserves_every_original_byte(self):
        before = self.pin.read_bytes()
        def fail(command, **kwargs):
            if command[:2] == ["nix", "build"]:
                return subprocess.CompletedProcess(command, 1, "", "error: network unreachable\n")
            return nix(command, **kwargs)
        with patch.object(module.subprocess, "run", side_effect=fail), self.assertRaises(ValueError):
            module.update(self.pin, snapshot(), apply=True)
        self.assertEqual(self.pin.read_bytes(), before)

    def test_prefetched_revision_mismatch_preserves_pin(self):
        before = self.pin.read_bytes()
        wrong = subprocess.CompletedProcess([], 0, json.dumps({"hash": SOURCE, "locked": {"rev": "c" * 40}}), "")
        with patch.object(module.subprocess, "run", return_value=wrong), self.assertRaises(ValueError):
            module.update(self.pin, snapshot(), apply=True)
        self.assertEqual(self.pin.read_bytes(), before)

    def test_bad_release_identity_fails(self):
        for mutation in [lambda s: s.update(upstreamRevision="b" * 40), lambda s: s["release"].update(prerelease=True),
                         lambda s: s["release"].update(tag_name="v0.84.0-beta.1"),
                         lambda s: s["tagRef"].update(ref="refs/tags/v0.83.0")]:
            data = copy.deepcopy(snapshot())
            mutation(data)
            with self.assertRaises(ValueError):
                module.candidate(data)

    def test_downgrade_and_moved_tag_are_refused(self):
        before = self.pin.read_bytes()
        with patch.object(module.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                module.update(self.pin, snapshot("0.82.0"), apply=True)
            with self.assertRaises(ValueError):
                module.update(self.pin, snapshot("0.83.0", "c" * 40), apply=True)
        run.assert_not_called()
        self.assertEqual(self.pin.read_bytes(), before)

    def test_concurrent_manual_edit_survives(self):
        manual = '{"manual":true}\n'
        def edit(command, **kwargs):
            self.pin.write_text(manual)
            return nix(command, **kwargs)
        with patch.object(module.subprocess, "run", side_effect=edit), self.assertRaises(ValueError):
            module.update(self.pin, snapshot(), apply=True)
        self.assertEqual(self.pin.read_text(), manual)


if __name__ == "__main__":
    unittest.main()
