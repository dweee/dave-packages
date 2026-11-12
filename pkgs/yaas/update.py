#!/usr/bin/env python3
"""Update YAAS master, its nested Cargo hash and generated Flutter lock together."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPOSITORY = "skrimix/yaas"
BRANCH = "master"


def discover():
    commit = json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{REPOSITORY}/commits/{BRANCH}"], text=True, timeout=60,
    ))
    return {"repository": REPOSITORY, "branch": BRANCH, "commit": commit}


def target(snapshot):
    if snapshot.get("repository") != REPOSITORY or snapshot.get("branch") != BRANCH:
        raise ValueError("YAAS follows the maintained upstream master, not nightly releases")
    commit = snapshot["commit"]
    if not re.fullmatch(r"[0-9a-f]{40}", commit["sha"]):
        raise ValueError("An exact upstream commit is required")
    date = datetime.datetime.fromisoformat(commit["commit"]["committer"]["date"].replace("Z", "+00:00"))
    if date.tzinfo is None:
        raise ValueError("Commit date must have a timezone")
    return commit["sha"], "0-unstable-" + date.date().isoformat()


def recipe_state(content):
    result = {}
    for key, pattern in [("revision", r'\brev = "([0-9a-f]{40})";'),
                         ("version", r'\bversion = "([^"]+)";')]:
        values = re.findall(pattern, content.decode())
        if len(values) != 1:
            raise ValueError("Expected one explicit YAAS " + key)
        result[key] = values[0]
    return result


def update(root, snapshot, apply=False):
    revision, version = target(snapshot)
    recipe = root / "pkgs/yaas/default.nix"
    lock = root / "pkgs/yaas/pubspec.lock.json"
    before = recipe.read_bytes()
    original_lock = lock.read_bytes()
    state = recipe_state(before)
    if not re.fullmatch(r"0-unstable-\d{4}-\d{2}-\d{2}", state["version"]):
        raise ValueError("Review the changed YAAS version policy before updating")
    if version < state["version"]:
        raise ValueError("Refusing an upstream date downgrade")
    source_changed = state != {"revision": revision, "version": version}
    report = {"package": "yaas", "oldVersion": state["version"], "newVersion": version,
              "oldRevision": state["revision"], "newRevision": revision,
              "changed": source_changed, "applied": False}
    if not apply:
        return report
    if recipe.read_bytes() != before or lock.read_bytes() != original_lock:
        raise ValueError("YAAS recipe changed during discovery")
    if source_changed:
        # nix-update refreshes fetchFromGitHub and the exposed nested cargoDeps.
        # The regex prevents its release-feed heuristic from choosing `nightly`.
        subprocess.run([
            "nix-update", "--flake", "--system", "x86_64-linux",
            "--version=branch=" + revision, "--version-regex=^(0-unstable-[0-9-]+)$",
            "--option", "max-jobs", "1", "--option", "cores", "2",
            "--option", "builders", "", "yaas",
        ], cwd=root, check=True, timeout=1800, stdout=sys.stderr)
    if recipe_state(recipe.read_bytes()) != {"revision": revision, "version": version}:
        raise ValueError("Maintained updater did not select the frozen upstream commit")
    source = json.loads(subprocess.check_output([
        "nix", "build", "--no-link", "--json", "--no-update-lock-file", "--no-write-lock-file",
        "--option", "max-jobs", "1", "--option", "cores", "2", "--builders", "",
        ".#packages.x86_64-linux.yaas.src",
    ], cwd=root, text=True, timeout=1800))[0]["outputs"]["out"]
    generated = json.loads(subprocess.check_output(
        ["yq", "-o=json", ".", str(Path(source) / "pubspec.lock")], text=True, timeout=30,
    ))
    if not isinstance(generated, dict) or not isinstance(generated.get("packages"), dict):
        raise ValueError("Generated Flutter lock is missing its package map")
    content = (json.dumps(generated, indent=2, ensure_ascii=False) + "\n").encode()
    if lock.read_bytes() != original_lock:
        raise ValueError("Flutter lock changed during source regeneration")
    if content != original_lock:
        temporary = lock.with_name(lock.name + ".update-tmp")
        with temporary.open("xb") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        if lock.read_bytes() != original_lock:
            temporary.unlink()
            raise ValueError("Flutter lock changed before publication")
        temporary.replace(lock)
    return report | {"changed": source_changed or content != original_lock,
                     "applied": source_changed or content != original_lock,
                     "flutterLockChanged": content != original_lock}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--write-snapshot", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    snapshot = json.loads(args.snapshot.read_text()) if args.snapshot else discover()
    target(snapshot)
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(json.dumps(update(args.root, snapshot, args.apply), indent=2))


if __name__ == "__main__":
    main()
