#!/usr/bin/env python3
"""Stable-release identity, source hash, version and no-change regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("lightning_update", ROOT / "pkgs/lightning/update.py")
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


def snapshot(version="0.10.5", revision="b" * 40):
    tag = "v" + version
    return {"version": 1, "repository": u.REPOSITORY,
            "release": {"tag_name": tag, "draft": False, "prerelease": False,
                        "html_url": f"https://github.com/{u.REPOSITORY}/releases/tag/{tag}"},
            "tagRef": {"ref": "refs/tags/" + tag, "object": {"type": "tag", "sha": "c" * 40}},
            "tagObjects": {"c" * 40: {"sha": "c" * 40, "object": {"type": "commit", "sha": revision}}}}


class Lightning(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.pin = Path(self.tmp.name) / "pin.json"
        self.pin.write_text(json.dumps({"version": "0.10.4", "revision": "a" * 40, "hash": "sha256-" + "A" * 43 + "="}))

    def test_live_discovery_resolves_release_and_annotated_tag_once(self):
        s = snapshot()
        with patch.object(u, "api", side_effect=[s["release"], s["tagRef"], s["tagObjects"]["c" * 40]]) as api:
            found = u.discover()
        self.assertEqual(found, s)
        self.assertEqual([c.args[0] for c in api.call_args_list], ["/releases/latest", "/git/ref/tags/v0.10.5", "/git/tags/" + "c" * 40])

    def test_apply_and_idempotency_do_not_reselect_upstream(self):
        before = self.pin.read_bytes()
        with patch.object(u, "prefetch", return_value="sha256-" + "B" * 43 + "=") as prefetch:
            self.assertTrue(u.update(self.pin, snapshot())["changed"])
            self.assertEqual(self.pin.read_bytes(), before)
            self.assertTrue(u.update(self.pin, snapshot(), True)["applied"])
            after = self.pin.read_bytes()
            self.assertFalse(u.update(self.pin, snapshot(), True)["changed"])
        self.assertEqual(prefetch.call_count, 1)
        self.assertEqual(self.pin.read_bytes(), after)

    def test_source_policy_draft_prerelease_and_tag_chain_fail_closed(self):
        changes = [lambda s: s.update(repository="other/source"),
                   lambda s: s["release"].update(draft=True),
                   lambda s: s["release"].update(prerelease=True),
                   lambda s: s["release"].update(html_url="https://example.invalid/release"),
                   lambda s: s["tagRef"].update(ref="refs/heads/main"),
                   lambda s: s["tagObjects"]["c" * 40]["object"].update(sha="main"),
                   lambda s: s["tagObjects"]["c" * 40]["object"].update(type="tag",sha="c" * 40)]
        before = self.pin.read_bytes()
        for change in changes:
            s = snapshot()
            change(s)
            with self.subTest(change=change), self.assertRaises((ValueError, KeyError)):
                u.update(self.pin, s, True)
        self.assertEqual(self.pin.read_bytes(), before)

    def test_downgrade_and_retag_require_review(self):
        for s in [snapshot("0.10.3"), snapshot("0.10.4")]:
            with self.assertRaises(ValueError):
                u.update(self.pin, s, True)

    def test_nix_hash_must_match_exact_commit_and_source_version(self):
        source = Path(self.tmp.name) / "source"
        source.mkdir()
        (source / "CMakeLists.txt").write_text("project(lightning VERSION 0.10.5)")
        f = {"hash": "sha256-" + "B" * 43 + "=", "storePath": str(source),
             "locked": {"type": "github", "owner": "Mizerd", "repo": "lightning", "rev": "b" * 40, "narHash": "sha256-" + "B" * 43 + "="}}
        with patch.object(u.subprocess, "check_output", return_value=json.dumps(f)):
            self.assertEqual(u.prefetch("b" * 40, "0.10.5"), f["hash"])
            with self.assertRaises(ValueError):
                u.prefetch("a" * 40, "0.10.5")
            with self.assertRaises(ValueError):
                u.prefetch("b" * 40, "0.10.6")

    def test_concurrent_pin_edit_is_preserved(self):
        def changed(*args):
            self.pin.write_text("manual edit")
            return "sha256-" + "B" * 43 + "="
        with patch.object(u, "prefetch", side_effect=changed), self.assertRaisesRegex(ValueError, "changed"):
            u.update(self.pin, snapshot(), True)
        self.assertEqual(self.pin.read_text(), "manual edit")


if __name__ == "__main__":
    unittest.main()
