#!/usr/bin/env python3
"""Frozen GeoIP discovery/application and public source-policy regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("geoip", ROOT / "scripts/update-geoip.py")
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


def release(repo, asset, tag="2026.11.11"):
    return {"tag_name": tag, "draft": False, "prerelease": False, "assets": [{
        "name": asset, "state": "uploaded", "size": 100,
        "browser_download_url": f"https://github.com/{repo}/releases/download/{tag}/{asset}",
        "digest": "sha256:" + "ab" * 32}]}


class GeoIP(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name, (repo, asset) in u.SOURCES.items():
            path = self.root / name
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(u.pin_for({"repo": repo, "asset": asset}, release(repo, asset, "2026.10.28"))) + "\n")
        self.snapshot = {"version": 1, "releases": {repo: release(repo, asset) for repo, asset in u.SOURCES.values()}}
        self.file = self.root / "snapshot.json"
        self.file.write_text(json.dumps(self.snapshot))
        p = patch.object(u, "ROOT", self.root)
        p.start()
        self.addCleanup(p.stop)

    def invoke(self, *args):
        with patch.object(sys, "argv", ["update-geoip.py", *map(str, args)]):
            return u.main()

    def contents(self):
        return {name: (self.root / name).read_bytes() for name in u.PINS}

    def test_snapshot_apply_then_idempotent_without_live_queries(self):
        with patch.object(u, "latest_release", side_effect=AssertionError("moving query")):
            before = self.contents()
            self.invoke("--snapshot", self.file, "--check")
            self.assertEqual(self.contents(), before)
            self.invoke("--snapshot", self.file, "--apply")
            after = self.contents()
            self.assertNotEqual(after, before)
            self.invoke("--snapshot", self.file, "--apply")
            self.assertEqual(self.contents(), after)

    def test_discovery_resolves_each_owner_once_without_writes(self):
        before = self.contents()
        with patch.object(u, "latest_release", side_effect=lambda repo: self.snapshot["releases"][repo]) as query:
            self.invoke("--write-snapshot", self.file)
        self.assertEqual(query.call_count, 2)
        self.assertEqual(self.contents(), before)
        self.assertEqual(json.loads(self.file.read_text()), self.snapshot)

    def test_invalid_second_asset_never_partially_applies_first(self):
        before = self.contents()
        repo = u.SOURCES[u.PINS[1]][0]
        self.snapshot["releases"][repo]["assets"][0]["digest"] = ""
        self.file.write_text(json.dumps(self.snapshot))
        with self.assertRaises(ValueError):
            self.invoke("--snapshot", self.file, "--apply")
        self.assertEqual(self.contents(), before)

    def test_bad_source_asset_digest_or_release_is_rejected(self):
        repo, asset = u.SOURCES[u.PINS[0]]
        changes = [lambda r: r.update(draft=True), lambda r: r.update(prerelease=True),
                   lambda r: r.update(tag_name="latest"),
                   lambda r: r["assets"][0].update(browser_download_url="https://git.monke.fail/private"),
                   lambda r: r["assets"][0].update(digest="sha256:" + "z" * 64),
                   lambda r: r["assets"][0].update(state="new"),
                   lambda r: r["assets"].append(copy.deepcopy(r["assets"][0]))]
        for change in changes:
            value = release(repo, asset)
            change(value)
            with self.subTest(change=change), self.assertRaises(ValueError):
                u.pin_for({"repo": repo, "asset": asset}, value)

    def test_manual_source_policy_is_preserved(self):
        path = self.root / u.PINS[0]
        value = json.loads(path.read_text())
        value["repo"] = "different/source"
        path.write_text(json.dumps(value))
        before = self.contents()
        with self.assertRaisesRegex(ValueError, "source policy"):
            self.invoke("--snapshot", self.file, "--apply")
        self.assertEqual(self.contents(), before)


if __name__ == "__main__":
    unittest.main()
