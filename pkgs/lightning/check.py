#!/usr/bin/env python3
"""Isolated, network-free checks of installed Lightning and upstream contracts."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

# Upstream tests that are stale against their own release. Each entry is
# version-bound, so a new release runs the full upstream suite again.
STALE_UPSTREAM_TESTS = {
    # v0.10.7 wrapped `.left(80)` as `.left(matrix::preview::kReplyPreviewMaxChars)`;
    # the test still expects the literal. reply_preview_contract() covers it.
    "0.10.7": {"test_followup_qml_contracts.FollowupQmlContracts.test_reply_entry_points_use_the_reply_preview"},
}
# Runs one upstream test module from the source root without its stale tests.
RUN_UPSTREAM_TESTS = """
import sys, unittest
sys.path.insert(0, "tests")
stale = set(sys.argv[2:])
def flat(suite):
    for test in suite:
        yield from flat(test) if isinstance(test, unittest.TestSuite) else [test]
tests = flat(unittest.defaultTestLoader.loadTestsFromName(sys.argv[1]))
suite = unittest.TestSuite(test for test in tests if test.id() not in stale)
sys.exit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())
"""


def reply_preview_contract(source):
    # Reply entry points and thread replies use the dedicated reply preview.
    for name in ("MessageDelegate.qml", "TimelinePane.qml"):
        text = (source / "qml" / name).read_text()
        if not re.search(r"var previewText = (?:root\.)?timelineModel\.replyPreviewForEvent\(eventId\)", text):
            raise RuntimeError(name + " must use the dedicated reply preview")
    thread = (source / "src/threads/ThreadController.cpp").read_text()
    if not re.search(r"m_replyToPreview = m_model\.replyPreviewForEvent\(eventId\)\s*\.left\(", thread):
        raise RuntimeError("Thread replies must use the dedicated reply preview")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    binary = args.package / "bin/lightning-matrix"
    records = []
    with tempfile.TemporaryDirectory(prefix="lightning-native-check-") as directory:
        env = os.environ.copy()
        env.update(HOME=directory, QT_QPA_PLATFORM="offscreen", LANG="C.UTF-8")
        if sys.platform.startswith("linux"):
            env["LD_BIND_NOW"] = "1"
        for key in ["XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR"]:
            path = Path(directory) / key.lower()
            path.mkdir(mode=0o700)
            env[key] = str(path)
        def run(name, argv, cwd=None):
            result = subprocess.run(argv, env=env, cwd=cwd, capture_output=True, text=True, timeout=120)
            records.append({"check": name, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
            if result.returncode:
                raise RuntimeError(name + " failed: " + result.stderr + result.stdout)
            return result.stdout
        version = run("version", [str(binary), "--version"])
        if "Lightning " + args.version not in version:
            raise RuntimeError("Installed binary version differs from source manifest")
        run("help", [str(binary), "--help"])
        run("image-format-status", [str(binary), "--image-format-status"])
        run("gstreamer-call-media-status", [str(binary), "--call-media-status"])
        run("spell-selftest", [str(binary), "--spell-selftest"])
        candidates = [args.package / "bin/.lightning-matrix-wrapped",
                      args.package / "Applications/Lightning.app/Contents/MacOS/.Lightning-wrapped"]
        executable = next((p for p in candidates if p.is_file()), binary)
        if sys.platform.startswith("linux"):
            links = run("dynamic-linkage", ["ldd", str(executable)])
            if "not found" in links or "libQt6Core" not in links:
                raise RuntimeError("Missing Qt or native shared library")
        elif sys.platform == "darwin":
            run("dynamic-linkage", ["otool", "-L", str(executable)])
        stale = sorted(STALE_UPSTREAM_TESTS.get(args.version, ()))
        for name in ["camera_fixed_modes", "followup_app_sources", "followup_qml_contracts", "gui5c_regressions"]:
            run("upstream-contract-" + name,
                [sys.executable, "-B", "-c", RUN_UPSTREAM_TESTS, "test_" + name, *stale], args.source)
        if stale:
            reply_preview_contract(args.source)
            records.append({"check": "skipped-stale-upstream-tests", "tests": stale})
    print(json.dumps({"version": args.version, "checks": records, "result": "PASS"}, indent=2))


if __name__ == "__main__":
    main()
