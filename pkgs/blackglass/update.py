#!/usr/bin/env python3
"""Pin Black Glass's maintained master without activating a desktop theme."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess

REPOSITORY = "https://www.opencode.net/phob1an/blackglass.git"
BRANCH = "master"
SHA = re.compile(r"[0-9a-f]{40}")


def discover():
    output = subprocess.check_output(
        ["git", "ls-remote", "--symref", REPOSITORY, "HEAD", "refs/heads/" + BRANCH],
        text=True, timeout=60,
    )
    lines = [line.split("\t") for line in output.splitlines()]
    if ["ref: refs/heads/" + BRANCH, "HEAD"] not in lines:
        raise ValueError("Upstream default branch changed; review its policy")
    heads = [value for value, name in lines if name in {"HEAD", "refs/heads/" + BRANCH} and SHA.fullmatch(value)]
    if len(heads) != 2 or len(set(heads)) != 1:
        raise ValueError("Expected one consistent upstream master commit")
    return {"repository": REPOSITORY, "branch": BRANCH, "revision": heads[0]}


def update(pin_file, snapshot, apply=False):
    if snapshot.get("repository") != REPOSITORY or snapshot.get("branch") != BRANCH:
        raise ValueError("Unexpected Black Glass upstream policy")
    revision = snapshot["revision"]
    if not isinstance(revision, str) or not SHA.fullmatch(revision):
        raise ValueError("Expected an immutable upstream revision")
    before = pin_file.read_bytes()
    current = json.loads(before)
    report = {"package": "blackglass", "oldRevision": current["revision"],
              "newRevision": revision, "oldVersion": current["version"],
              "changed": revision != current["revision"], "applied": False}
    if not report["changed"] or not apply:
        return report
    fetched = json.loads(subprocess.check_output([
        "nix-prefetch-git", "--quiet", "--url", REPOSITORY, "--rev", revision,
    ], text=True, timeout=1800))
    if fetched.get("url") != REPOSITORY or fetched.get("rev") != revision:
        raise ValueError("Prefetch did not return the exact selected source")
    if any(fetched.get(key) is not False for key in ["fetchLFS", "fetchSubmodules", "deepClone", "leaveDotGit"]):
        raise ValueError("Unexpected Git source fetch semantics")
    if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", fetched["hash"]):
        raise ValueError("Missing source NAR SHA256")
    date = datetime.datetime.fromisoformat(fetched["date"])
    if date.tzinfo is None:
        raise ValueError("Source commit date must have a timezone")
    version = "0-unstable-" + date.date().isoformat()
    if not re.fullmatch(r"0-unstable-\d{4}-\d{2}-\d{2}", current["version"]) or version < current["version"]:
        raise ValueError("Changed version policy or date downgrade requires review")
    proposed = {"version": version, "revision": revision, "hash": fetched["hash"]}
    if pin_file.read_bytes() != before:
        raise ValueError("Pin changed during prefetch; refusing overwrite")
    temporary = pin_file.with_name(pin_file.name + ".update-tmp")
    with temporary.open("x") as output:
        output.write(json.dumps(proposed, indent=2) + "\n")
        output.flush()
        os.fsync(output.fileno())
    if pin_file.read_bytes() != before:
        temporary.unlink()
        raise ValueError("Pin changed before publication; refusing overwrite")
    temporary.replace(pin_file)
    return report | {"newVersion": version, "hash": fetched["hash"], "applied": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pin-file", type=Path, default=Path(__file__).with_name("pin.json"))
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--write-snapshot", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    snapshot = json.loads(args.snapshot.read_text()) if args.snapshot else discover()
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(json.dumps(update(args.pin_file, snapshot, args.apply), indent=2))


if __name__ == "__main__":
    main()
