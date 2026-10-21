#!/usr/bin/env python3
"""Keep cache-only outputs out of every public transfer and log path."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("cache_only", ROOT / "ci/build-cache-only.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
spec = importlib.util.spec_from_file_location("cache_matrix", ROOT / "ci/cache-only-matrix.py")
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)
PATH = "/nix/store/" + "a" * 32 + "-approved-unfree"

class CacheOnlyBoundary(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.calls = []
        self.env = {"RUNNER_TEMP": self.directory.name, "ATTIC_TOKEN": "synthetic-private-token"}
        self.graph = {PATH + ".drv": {"outputs": {"out": {}}, "env": {"license": "unfree"}}}
        self.runtime = PATH
        self.failure = None

    def run_quiet(self, args, env, *, stdout=None):
        self.calls.append((args, env.copy()))
        if self.failure and self.failure in args:
            raise subprocess.CalledProcessError(1, args)
        if args[0] == "nix" and args[1] == "eval":
            value = "x86_64-linux"
        elif args[0] == "nix" and args[1] == "derivation":
            value = json.dumps(self.graph)
        elif "nixpkgs#attic-client" in args:
            value = PATH
        elif args[0] == "nix" and args[1] == "build":
            stdout.write(PATH + "\n")
            value = ""
        elif args[0] == "nix-store":
            value = self.runtime
        else:
            self.assertTrue(args[1].endswith("/ci/push-attic.py"))
            manifest = Path(args[args.index("--outputs") + 1])
            self.assertEqual(manifest.read_text(), PATH + "\n")
            self.manifest = manifest
            self.assertIsNotNone(stdout)  # uploader progress cannot reach public logs
            self.assertEqual(env["ATTIC_TOKEN"], self.env["ATTIC_TOKEN"])
            self.assertEqual(env["ATTIC_CACHE"], "flakey")
            self.assertEqual(env["ATTIC_ENDPOINT"], "https://attic.monke.fail")
            value = ""
        return subprocess.CompletedProcess(args, 0, stdout=value)

    def run_build(self):
        with patch.dict(os.environ, self.env, clear=True), patch.object(module, "quiet", side_effect=self.run_quiet):
            module.build("x86_64-linux", "veracrypt")

    def test_unfree_allowed_only_in_direct_private_pipeline_and_manifest_removed(self):
        self.run_build()
        self.assertFalse(self.manifest.exists())
        for args, env in self.calls[:-1]:
            self.assertNotIn("ATTIC_TOKEN", env)
            self.assertNotIn("synthetic-private-token", " ".join(args))
        self.assertTrue(any("cacheOnlyPackages.x86_64-linux.veracrypt" in " ".join(a) for a, _ in self.calls))
        self.assertFalse(any("export" in a or "--export" in a for a, _ in self.calls))

    def test_disc_and_subnetter_in_transitive_graph_stop_before_build(self):
        for name in ["wiicompiled-disc-rmcp01", "wiicompiled-translated", "subnetter"]:
            with self.subTest(name=name):
                self.calls.clear()
                self.graph[PATH + ".drv"]["env"]["dependency"] = name
                with self.assertRaises(ValueError):
                    self.run_build()
                self.assertFalse(any("build" in a for a, _ in self.calls))

    def test_unknown_package_rejected_before_nix_or_credentials(self):
        with patch.object(module, "quiet") as run:
            with self.assertRaises(ValueError): module.build("x86_64-linux", "wiicompiled")
            run.assert_not_called()

    def test_build_failure_never_uploads(self):
        self.failure = "--print-out-paths"
        with self.assertRaises(subprocess.CalledProcessError): self.run_build()
        self.assertFalse(any(a[0] == module.sys.executable for a, _ in self.calls))

    def test_runtime_disc_reference_stops_before_upload(self):
        self.runtime = PATH + "-wiicompiled-disc-rmcp01"
        with self.assertRaises(ValueError): self.run_build()
        self.assertFalse(any(a[0] == module.sys.executable for a, _ in self.calls))

    def test_unknown_graph_format_fails_closed(self):
        self.graph = {"version": 2, "unexpected": "data"}
        with self.assertRaises(ValueError): self.run_build()
        self.assertFalse(any("build" in a for a, _ in self.calls))

    def test_failed_cli_never_prints_build_stdout_stderr_or_credential(self):
        tools = Path(self.directory.name) / "tools"
        tools.mkdir()
        fake = tools / "nix"
        fake.write_text("#!/bin/sh\necho sensitive-build-stdout\necho sensitive-build-stderr >&2\nexit 1\n")
        fake.chmod(0o700)
        env = dict(os.environ, **self.env, TARGET_SYSTEM="x86_64-linux", TARGET_PACKAGE="veracrypt")
        env["PATH"] = str(tools) + os.pathsep + os.environ["PATH"]
        result = subprocess.run([module.sys.executable, str(ROOT / "ci/build-cache-only.py")],
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("No artifacts or diagnostic logs were published", result.stderr)
        for private in ["sensitive-build-stdout", "sensitive-build-stderr", self.env["ATTIC_TOKEN"]]:
            self.assertNotIn(private, result.stdout + result.stderr)

    def test_public_matrix_and_backup_workflow_exclude_cache_only_jobs(self):
        free = json.loads((ROOT / "nix/platforms.json").read_text())
        private = json.loads((ROOT / "nix/cache-only-platforms.json").read_text())
        for system, names in private.items():
            self.assertFalse(set(names) & set(free[system]))
        workflow = (ROOT / ".github/workflows/cache-only.yml").read_text()
        self.assertNotIn("pull_request:", workflow)
        for forbidden in ["upload-artifact", "download-artifact", "transfer-attic", "gh release", "contents: write"]:
            self.assertNotIn(forbidden, workflow)
        self.assertEqual(workflow.count("github.ref == format('refs/heads/{0}', github.event.repository.default_branch)"), 2)
        archive = (ROOT / ".github/workflows/archive-packages.yml").read_text()
        self.assertNotIn("Dave packages cache only", archive)

    def test_cache_only_selection_and_native_runners(self):
        jobs = matrix.matrix("all")["include"]
        self.assertEqual(len(jobs), 13)
        self.assertEqual({j["runner"] for j in jobs}, {"ubuntu-24.04", "ubuntu-24.04-arm", "macos-15"})
        self.assertEqual(len(matrix.matrix("keyguard")["include"]), 3)
        self.assertEqual(matrix.matrix("spotify")["include"], [
            {"system": "aarch64-darwin", "runner": "macos-15", "package": "spotify"}
        ])
        with self.assertRaises(ValueError): matrix.matrix("wiicompiled-disc-rmcp01")

if __name__ == "__main__": unittest.main()
