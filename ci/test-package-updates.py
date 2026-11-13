#!/usr/bin/env python3
import base64
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_updates", SOURCE / "ci/package-updates.py")
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)
PIN = "pkgs/codexbar/cli-pin.json"


def pins(version):
    return (json.dumps({"version": version, "assets": {
        system: {"name": f"CodexBarCLI-v{version}-linux-{arch}.tar.gz", "hash": "sha256-" + "A" * 43 + "="}
        for system, arch in [("x86_64-linux", "x86_64"), ("aarch64-linux", "aarch64")]
    }}, indent=2) + "\n").encode()


class Publication(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        directory = Path(self.temporary.name)
        self.root, self.remote = directory / "checkout", directory / "remote.git"
        self.root.mkdir()
        self.env_patch = patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
                                                "AUTOMATION_TOKEN": "fixture-not-a-secret"})
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)
        self.g("init", "-q", "--initial-branch=main")
        self.g("config", "user.name", "Package updater")
        self.g("config", "user.email", "package-updater@monke.fail")
        (self.root / PIN).parent.mkdir(parents=True)
        (self.root / PIN).write_bytes(pins("1.0.0"))
        self.g("add", ".")
        self.g("commit", "-qm", "fixture base")
        subprocess.run(["git", "init", "-q", "--bare", str(self.remote)], check=True)
        self.g("remote", "add", "origin", str(self.remote))
        self.g("push", "-q", "origin", "HEAD:refs/heads/main")
        self.base = self.g("rev-parse", "HEAD")
        self.rules = {"repository": "fixture/catalog", "branch": "main", "remote": str(self.remote), "forge": "github"}
        self.calls, self.pr = [], None
        for obj, field, value in [(u, "ROOT", self.root), (u.channel, "ROOT", self.root)]:
            p = patch.object(obj, field, value)
            p.start()
            self.addCleanup(p.stop)
        self.config_patch = patch.object(u, "configuration", return_value=({}, self.rules, {PIN}))
        self.config_mock = self.config_patch.start()
        self.addCleanup(self.config_patch.stop)
        for name, kwargs in [("api", {"side_effect": self.api}), ("dispatch_input_checks", {"return_value": None})]:
            p = patch.object(u.forge, name, **kwargs)
            p.start()
            self.addCleanup(p.stop)

    def g(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True, stderr=subprocess.DEVNULL).strip()

    def remote_tip(self):
        value = self.g("ls-remote", "--heads", str(self.remote), "refs/heads/" + u.BRANCH)
        return value.split()[0] if value else None

    def proposal(self, version="3.0.0"):
        old, new = (self.root / PIN).read_bytes(), pins(version)
        value = {"version": 1, "repository": self.rules["repository"], "base": self.base,
                 "reports": {"codexbar-cli": {"newVersion": version}},
                 "files": {PIN: {"oldSHA256": u.digest(old), "newSHA256": u.digest(new),
                                  "content": base64.b64encode(new).decode()}}}
        path = Path(self.temporary.name) / "proposal.json"
        path.write_text(json.dumps(value))
        return path

    def old_branch(self):
        (self.root / PIN).write_bytes(pins("2.0.0"))
        self.g("add", PIN)
        tree = self.g("write-tree")
        head = self.g("commit-tree", tree, "-p", self.base, "-m", "old automated pins")
        self.g("push", "-q", "origin", head + ":refs/heads/" + u.BRANCH)
        self.g("restore", "--source=HEAD", "--staged", "--worktree", PIN)
        self.pr = {"number": 7, "body": u.MARKER, "state": "open", "base": {"ref": "main"},
                   "head": {"ref": u.BRANCH, "sha": head, "repo": {"full_name": self.rules["repository"]}},
                   "html_url": "https://example.invalid/pull/7"}
        return head

    def api(self, rules, method, endpoint, data=None):
        self.calls.append((method, endpoint, data))
        if method == "GET" and "/branches/" in endpoint:
            return {"commit": {"sha": self.base}}
        if method == "GET" and "/pulls?" in endpoint:
            return [copy.deepcopy(self.pr)] if self.pr else []
        if method == "GET" and "/check-runs?" in endpoint:
            return {"check_runs": []}
        if method == "GET" and "/statuses?" in endpoint:
            return []
        if method == "GET" and endpoint.endswith("/pulls/7"):
            result = copy.deepcopy(self.pr)
            result["head"]["sha"] = self.remote_tip()
            return result
        if method == "POST" and endpoint.endswith("/pulls"):
            return {"number": 7, "html_url": "https://example.invalid/pull/7"}
        if method in {"POST", "PATCH"}:
            return {}
        raise AssertionError((method, endpoint))

    def test_first_publication_creates_one_fixed_branch_and_pr(self):
        head = u.publish(self.proposal())
        self.assertEqual(head, self.remote_tip())
        self.assertEqual(self.g("show", head + ":" + PIN), pins("3.0.0").decode().strip())
        created = [c for c in self.calls if c[0] == "POST" and c[1].endswith("/pulls")]
        self.assertEqual(len(created), 1)
        self.assertEqual(created[0][2]["head"], u.BRANCH)

    def test_reuse_keeps_old_head_and_new_canonical_base_without_force(self):
        old = self.old_branch()
        (self.root / "README.md").write_text("canonical source improvement\n")
        self.g("add", "README.md")
        self.g("commit", "-qm", "advance canonical source")
        self.g("push", "-q", "origin", "HEAD:refs/heads/main")
        self.base = self.g("rev-parse", "HEAD")
        head = u.publish(self.proposal())
        for ancestor in [old, self.base]:
            self.g("merge-base", "--is-ancestor", ancestor, head)
        self.assertEqual(self.g("show", head + ":README.md"), "canonical source improvement")
        self.assertFalse(any(c[0] == "POST" and c[1].endswith("/pulls") for c in self.calls))
        self.assertTrue(any(c[1].endswith("/comments") for c in self.calls))

    def test_manual_source_commit_is_preserved(self):
        old = self.old_branch()
        self.g("switch", "--detach", "-q", old)
        (self.root / "source.py").write_text("manual source fix\n")
        self.g("add", "source.py")
        self.g("commit", "-qm", "manual source fix")
        manual = self.g("rev-parse", "HEAD")
        self.g("push", "-q", "origin", "HEAD:refs/heads/" + u.BRANCH)
        self.g("switch", "-q", "main")
        self.pr["head"]["sha"] = manual
        with self.assertRaisesRegex(ValueError, "manual source"):
            u.publish(self.proposal())
        self.assertEqual(self.remote_tip(), manual)

    def test_manual_pin_commit_is_preserved_too(self):
        old = self.old_branch()
        self.g("switch", "--detach", "-q", old)
        (self.root / PIN).write_bytes(pins("2.1.0"))
        self.g("add", PIN)
        self.g("-c", "user.name=Human", "-c", "user.email=human@example.invalid", "commit", "-qm", "manual pin adjustment")
        manual = self.g("rev-parse", "HEAD")
        self.g("push", "-q", "origin", "HEAD:refs/heads/" + u.BRANCH)
        self.g("switch", "-q", "main")
        self.pr["head"]["sha"] = manual
        with self.assertRaisesRegex(ValueError, "manual source"):
            u.publish(self.proposal())
        self.assertEqual(self.remote_tip(), manual)

    def test_active_checks_do_not_interrupt_current_candidate(self):
        old = self.old_branch()
        with patch.object(u, "checks_running", return_value=True):
            self.assertEqual(u.publish(self.proposal()), old)
        self.assertEqual(self.remote_tip(), old)
        self.assertEqual(self.g("status", "--porcelain"), "")

    def test_concurrent_branch_advance_rejects_publication(self):
        old = self.old_branch()
        with patch.object(u, "remote_head", side_effect=[old, "e" * 40]), self.assertRaisesRegex(ValueError, "advanced"):
            u.publish(self.proposal())
        self.assertEqual(self.remote_tip(), old)

    def test_legacy_guard_runs_before_any_routine_branch_is_created(self):
        with patch.object(u, "protect_legacy_package_prs", side_effect=ValueError("legacy preservation")), \
                self.assertRaisesRegex(ValueError, "legacy preservation"):
            u.publish(self.proposal())
        self.assertIsNone(self.remote_tip())
        self.assertFalse(any(method != "GET" for method, _, _ in self.calls))
        self.assertEqual(self.g("status", "--porcelain"), "")

    def test_bad_hash_and_undeclared_paths_never_publish(self):
        for change in ["hash", "path"]:
            path = self.proposal()
            value = json.loads(path.read_text())
            if change == "hash":
                value["files"][PIN]["newSHA256"] = "0" * 64
            else:
                value["files"]["../escape"] = value["files"].pop(PIN)
            path.write_text(json.dumps(value))
            with self.subTest(change=change), self.assertRaises(ValueError):
                u.publish(path)
            self.assertIsNone(self.remote_tip())

    def test_no_update_is_a_true_noop(self):
        path = self.proposal()
        value = json.loads(path.read_text())
        value["files"] = {}
        path.write_text(json.dumps(value))
        self.assertIsNone(u.publish(path))
        self.assertEqual(self.calls, [])
        self.assertEqual(self.g("status", "--porcelain"), "")

    def test_prepare_generates_data_only_and_reuses_frozen_targets(self):
        script = self.root / "pkgs/codexbar/update.py"
        script.write_text('''import argparse,json,pathlib
p=argparse.ArgumentParser();p.add_argument('--write-snapshot');p.add_argument('--snapshot');p.add_argument('--apply',action='store_true');a=p.parse_args()
f=pathlib.Path('pkgs/codexbar/cli-pin.json');old=json.loads(f.read_text());new={'version':'2.0.0','assets':{k:{'name':v['name'].replace('v'+old['version'],'v2.0.0'),'hash':v['hash']} for k,v in old['assets'].items()}}
if a.write_snapshot:pathlib.Path(a.write_snapshot).write_text('{"target":"2.0.0"}')
if a.apply:f.write_text(json.dumps(new)+'\\n')
print(json.dumps({'changed':old!=new}))
''')
        self.g("add", "pkgs/codexbar/update.py")
        self.g("commit", "-qm", "fixture canonical handler")
        self.base = self.g("rev-parse", "HEAD")
        policy = {"handlers": {"codexbar-cli": {"script": "pkgs/codexbar/update.py", "files": [PIN]},
                               "unused": {"script": "pkgs/unused/update.py", "files": ["pkgs/unused/pin.json"]}}}
        self.config_mock.return_value = policy, self.rules, {PIN}
        proposal = Path(self.temporary.name) / "prepared.json"
        value = u.prepare(proposal, handler="codexbar-cli")
        self.assertEqual(value["base"], self.base)
        self.assertEqual(set(value["files"]), {PIN})
        self.assertEqual(json.loads(base64.b64decode(value["files"][PIN]["content"]))["version"], "2.0.0")
        self.g("add", PIN)
        self.g("commit", "-qm", "fixture accept generated pins")
        frozen = Path(self.temporary.name) / "snapshots"
        frozen.mkdir()
        (frozen / "codexbar-cli.json").write_text('{"target":"2.0.0"}')
        again = u.prepare(proposal, frozen, handler="codexbar-cli")
        self.assertEqual(again["files"], {})
        self.assertEqual(self.g("status", "--porcelain"), "")


class GuardTests(unittest.TestCase):
    def test_actual_handler_registry_has_disjoint_scoped_files(self):
        policy, rules, files = u.configuration()
        self.assertEqual(rules["repository"], "dweee/dave-packages")
        self.assertEqual(len(files), sum(len(p["files"]) for p in policy["handlers"].values()))

    def test_lightning_manifest_rejects_code_and_floating_revisions(self):
        path = "pkgs/lightning/pin.json"
        pin = {"version": "0.10.5", "revision": "b" * 40, "hash": "sha256-" + "A" * 43 + "="}
        valid = u.normalized(path, json.dumps(pin).encode())
        self.assertEqual(valid, u.normalized(path, json.dumps(pin | {"version": "0.10.6", "revision": "c" * 40}).encode()))
        for edit in [{"revision": "main"}, {"extra": "builtins.getEnv"}, {"hash": "sha256-fake"}]:
            with self.assertRaises(ValueError):
                u.normalized(path, json.dumps(pin | edit).encode())

    def test_geoip_normalizer_preserves_sources_and_release_bound_urls(self):
        name = "pkgs/byparr/geoip.json"
        old = (SOURCE / name).read_bytes()
        new = json.loads(old)
        new["release"] = "2026.11.12"
        new["url"] = "https://github.com/daijro/geoip-all-in-one/releases/download/2026.11.12/geoip-aio-all.mmdb.zip"
        u.validate_change(name, old, json.dumps(new).encode())
        new["url"] = "https://example.invalid/floating"
        with self.assertRaises(ValueError):
            u.validate_change(name, old, json.dumps(new).encode())

    def test_unincorporated_legacy_geoip_pr_is_preserved_without_replacement(self):
        path = "pkgs/byparr/geoip.json"
        pin = (SOURCE / path).read_bytes()
        pr = {"head": {"ref": "automation/geoip-previous", "sha": "b" * 40,
                       "repo": {"full_name": "fixture/catalog"}}, "base": {"ref": "main"}, "draft": False}
        with patch.object(u, "git", side_effect=["", "b" * 40, "c" * 40, path]), \
                patch.object(u.subprocess, "check_output", side_effect=[pin, pin]), \
                self.assertRaisesRegex(ValueError, "existing GeoIP PR"):
            u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"},
                                      [pr], "a" * 40, {path}, {})

    def test_incorporated_legacy_geoip_ancestry_does_not_block_next_pin_set(self):
        pr = {"head": {"ref": "automation/geoip-previous", "sha": "b" * 40,
                       "repo": {"full_name": "fixture/catalog"}}, "base": {"ref": "main"}, "draft": False}
        with patch.object(u, "git", side_effect=["", "b" * 40, "b" * 40, ""]):
            u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"},
                                      [pr], "a" * 40, {"pkgs/byparr/geoip.json"}, {})

    def test_unincorporated_legacy_horizon_pr_is_preserved(self):
        path = "pkgs/horizon/sources.json"
        pin = (SOURCE / path).read_bytes()
        pr = {"head": {"ref": "automation/horizon-previous", "sha": "b" * 40,
                       "repo": {"full_name": "fixture/catalog"}}, "base": {"ref": "main"}, "draft": False}
        with patch.object(u, "git", side_effect=["", "b" * 40, "c" * 40, path]), \
                patch.object(u.subprocess, "check_output", side_effect=[pin, pin]), \
                self.assertRaisesRegex(ValueError, "existing Horizon PR"):
            u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"}, [pr], "a" * 40, {path}, {})

    def test_incorporated_horizon_ancestry_allows_the_next_proposal(self):
        pr = {"head": {"ref": "automation/horizon-previous", "sha": "b" * 40,
                       "repo": {"full_name": "fixture/catalog"}}, "base": {"ref": "main"}, "draft": False}
        with patch.object(u, "git", side_effect=["", "b" * 40, "b" * 40, ""]):
            u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"}, [pr], "a" * 40, {"pkgs/horizon/sources.json"}, {})

    def test_horizon_head_change_and_manual_scope_fail_closed(self):
        pr = {"head": {"ref": "automation/horizon-previous", "sha": "b" * 40,
                       "repo": {"full_name": "fixture/catalog"}}, "base": {"ref": "main"}, "draft": False}
        for outputs, message in [(["", "c" * 40], "advanced"),
                                 (["", "b" * 40, "c" * 40, "pkgs/horizon/sources.json\nREADME.md"],
                                  "other source changes")]:
            with self.subTest(message=message), patch.object(u, "git", side_effect=outputs), \
                    self.assertRaisesRegex(ValueError, message):
                u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"}, [pr], "a" * 40, {"pkgs/horizon/sources.json"}, {})

    def test_held_or_foreign_horizon_pr_is_preserved_before_fetch(self):
        original = {"head": {"ref": "automation/horizon-previous", "sha": "b" * 40,
                             "repo": {"full_name": "fixture/catalog"}}, "base": {"ref": "main"}, "draft": False}
        for case in ["draft", "base", "repository"]:
            pr = copy.deepcopy(original)
            if case == "draft":
                pr["draft"] = True
            elif case == "base":
                pr["base"]["ref"] = "held"
            else:
                pr["head"]["repo"]["full_name"] = "other/catalog"
            with self.subTest(case=case), patch.object(u, "git") as git, \
                    self.assertRaisesRegex(ValueError, "held or manually owned Horizon"):
                u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"}, [pr], "a" * 40, {"pkgs/horizon/sources.json"}, {})
            git.assert_not_called()

    def test_unrelated_handler_does_not_fetch_legacy_horizon(self):
        pr = {"head": {"ref": "automation/horizon-previous"}}
        with patch.object(u, "git") as git:
            u.protect_legacy_package_prs({"repository": "fixture/catalog", "branch": "main", "remote": "fixture"}, [pr], "a" * 40, {PIN}, {})
        git.assert_not_called()

    def test_yaas_source_code_cannot_hide_inside_a_pin_update(self):
        text = (SOURCE / "pkgs/yaas/default.nix").read_bytes()
        u.validate_change("pkgs/yaas/default.nix", text, text.replace(b"2026-10-29", b"2026-11-01"))
        with self.assertRaises(ValueError):
            u.validate_change("pkgs/yaas/default.nix", text, text + b"\n# manual source work\n")

    def test_open_prs_are_paginated_and_repeated_pages_fail_closed(self):
        first = [{"number": number} for number in range(100)]
        with patch.object(u.forge, "api", side_effect=[first, [{"number": 100}]]) as api:
            self.assertEqual(len(u.open_prs({"repository": "fixture/catalog"})), 101)
        self.assertIn("page=2", api.call_args.args[2])
        with patch.object(u.forge, "api", side_effect=[first, first]), self.assertRaises(ValueError):
            u.open_prs({"repository": "fixture/catalog"})

    def test_pending_status_is_not_hidden_by_a_failed_context(self):
        with patch.object(u.forge, "api", side_effect=[{"check_runs": []}, [
            {"context": "failed", "state": "failure"}, {"context": "native", "state": "pending"}]]):
            self.assertTrue(u.checks_running({"repository": "fixture/catalog"}, "a" * 40))

    def test_old_pending_status_is_superseded_by_its_newer_success(self):
        with patch.object(u.forge, "api", side_effect=[{"check_runs": []}, [
            {"context": "native", "state": "success"}, {"context": "native", "state": "pending"}]]):
            self.assertFalse(u.checks_running({"repository": "fixture/catalog"}, "a" * 40))


if __name__ == "__main__":
    unittest.main()
