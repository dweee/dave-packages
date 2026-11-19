#!/usr/bin/env python3
"""Discover the public owner channel; publication uses automation-forge.py inputs."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("input_tools", ROOT / "ci/update-inputs.py")
inputs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inputs)
NAME = "wiicompiled"
URL = "https://github.com/dweee/Wiicompiled.git"
SOURCE = "git+" + URL + "?ref=flakey&submodules=1"


def validate(locked):
    if (locked.get("type") != "git" or locked.get("url") != URL
            or locked.get("ref") != "flakey" or locked.get("submodules") is not True
            or not re.fullmatch(r"[0-9a-f]{40}", locked.get("rev", ""))
            or not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", locked.get("narHash", ""))):
        raise ValueError("Unreviewed Wii source identity")
    return locked


def discover():
    rule = json.loads((ROOT / "ci/tracking-inputs.json").read_text())["inputs"][NAME]
    if rule != {"source": SOURCE}:
        raise ValueError("Unreviewed Wii tracking policy")
    fetched = json.loads(inputs.run("nix", "flake", "prefetch", "--json", "--refresh",
                                    "--option", "accept-flake-config", "false", SOURCE))
    return {"version": 1, "locked": validate(fetched["locked"])}


def update(snapshot, apply=False):
    if set(snapshot) != {"version", "locked"} or snapshot["version"] != 1:
        raise ValueError("Unknown Wii source snapshot")
    target = validate(snapshot["locked"])
    lockfile = ROOT / "flake.lock"
    before = json.loads(lockfile.read_text())
    current = validate(inputs.root_node(before, NAME)["locked"])
    report = {"package": NAME, "oldRevision": current["rev"], "newRevision": target["rev"],
              "changed": current["rev"] != target["rev"], "applied": False}
    if current["rev"] == target["rev"]:
        if current["narHash"] != target["narHash"]:
            raise ValueError("Immutable source hash changed")
        return report
    if not apply:
        return report
    if inputs.run("git", "status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Wii input updates require a clean checkout")
    flake = ROOT / "flake.nix"
    text = flake.read_text()
    match = inputs.url_match(text, NAME)
    if match[1] != inputs.pin_url(current):
        raise ValueError("Wii source declaration and lock disagree")
    exact = inputs.pin_url(target)
    inputs.run("nix", "flake", "lock", "--option", "accept-flake-config", "false",
               "--override-input", NAME, exact)
    after = json.loads(lockfile.read_text())
    actual = validate(inputs.root_node(after, NAME)["locked"])
    if actual["rev"] != target["rev"] or actual["narHash"] != target["narHash"]:
        raise ValueError("Nix resolved a different Wii source")
    key = before["nodes"][before["root"]]["inputs"][NAME]
    if set(after["nodes"]) != set(before["nodes"]) or any(after["nodes"][k] != v for k, v in before["nodes"].items() if k != key):
        raise ValueError("Unrelated input changed; preserve for review")
    flake.write_text(text[:match.start(1)] + exact + text[match.end(1):])
    inputs.run("nix", "flake", "lock", "--option", "accept-flake-config", "false")
    owners = ROOT / "nix/forks.json"
    records = json.loads(owners.read_text())
    records[NAME]["revision"] = target["rev"]
    owners.write_text(json.dumps(records, indent=2) + "\n")
    return report | {"applied": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--snapshot", type=Path)
    selection.add_argument("--write-snapshot", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check and args.apply:
        parser.error("--check cannot apply changes")
    snapshot = json.loads(args.snapshot.read_text()) if args.snapshot else discover()
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(json.dumps(update(snapshot, args.apply), indent=2))


if __name__ == "__main__":
    main()
