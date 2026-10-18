#!/usr/bin/env python3
"""Check first-party publication metadata for private operator material.

This current-tree check complements the private all-ref/history and secret
reviews. Vendored application sources and localization data are outside its
scope; scanner diagnostics report paths and rule names, never matched values.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

RULES = {
    "operator-path": re.compile(r"(?:machines/|users/[a-z][a-z0-9_-]*/|/persist/|/var/lib/private/|\.t3/(?:scratch|worktrees)/|\.local/state/flakey-builds/)", re.I),
    "personal-path": re.compile(r"/(?:Users|home)/(?:d|dave)(?:/|\b)|/etc/profiles/per-user/d\b", re.I),
    "encrypted-secret": re.compile(r"age-encryption\.org/v1|ENC\[AES256_GCM|BEGIN PGP MESSAGE|[a-zA-Z0-9_.-]+\.age\b"),
    "private-report": re.compile(r"(?:consolidated-handoff|private[-_ ]audit|chat[-_ ]histor(?:y|ies)|runtime override|pre-upgrade stopped-world)", re.I),
}
ROOT_FILES = {"README.md", "flake.nix", "flake.lock"}
OPERATOR_NAMES = {"validation.json", "provenance.json", "fork.json", "upstream.json"}


def included(path):
    value = str(path)
    if value.startswith("pkgs/wiicompiled/source/"):
        return False
    # Test fixtures contain deliberately prohibited examples, so inspect the
    # implementation itself separately through unit tests and private reviews.
    if value.startswith("ci/test-") or value == "ci/check-public-source.py":
        return False
    return path.name in ROOT_FILES or value.startswith(("nix/", "ci/", ".github/", "pkgs/")) and path.suffix in {".md", ".nix", ".json", ".py", ".yml", ".yaml"}


def inspect(path, content):
    findings = []
    if path.name.lower() in OPERATOR_NAMES or any(p in {".codex", ".cursor", ".claude", "chat-history"} for p in path.parts):
        findings.append("operator-artifact")
    findings.extend(rule for rule, pattern in RULES.items() if pattern.search(content))
    return findings


def check(root):
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
    failures = []
    for value in paths:
        if not value:
            continue
        path = Path(value)
        if included(path) and (root / path).is_file():
            failures.extend((value, rule) for rule in inspect(path, (root / path).read_text()))
    platforms = json.loads((root / "nix/platforms.json").read_text())
    avf = [name for packages in platforms.values() for name in packages if name.startswith("linux-") and name.endswith("-avf")]
    if avf != ["linux-android-avf"]:
        failures.append(("nix/platforms.json", "portable-avf-package-name"))
    if "nixosModules.android-avf-kernel-patches" not in (root / "flake.nix").read_text():
        failures.append(("flake.nix", "portable-avf-module-name"))
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    failures = check(args.root)
    for path, rule in failures:
        print(f"Public source boundary failed: {path} ({rule})", file=sys.stderr)
    return int(bool(failures))


if __name__ == "__main__":
    sys.exit(main())
