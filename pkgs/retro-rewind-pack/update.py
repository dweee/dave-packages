#!/usr/bin/env python3
"""Resolve the maintained Retro Rewind install pointer and pin its exact ZIP."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess

POINTER = "https://update.rwfc.net/RetroRewind/RetroRewindInstall.txt"
ZIP = "https://cdn.update.rwfc.net/RetroRewind/zip/{}-full.zip"


def version_from_pointer(text):
    match = re.fullmatch(re.escape(ZIP).replace(re.escape("{}"), r"(\d+\.\d+\.\d+)"), text.strip())
    if not match:
        raise ValueError("Install pointer is not the expected official full ZIP URL")
    return match[1]


def discover():
    # Use the same transport as the maintained upstream pointer procedure.
    pointer = subprocess.check_output(
        ["curl", "--fail", "--silent", "--show-error", "--max-time", "60", POINTER],
        text=True, timeout=65,
    )
    return {"pointerSource": POINTER, "installUrl": ZIP.format(version_from_pointer(pointer)),
            "observedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()}


def update(pin_file, snapshot, apply=False):
    if snapshot.get("pointerSource") != POINTER:
        raise ValueError("Unexpected pointer source")
    version = version_from_pointer(snapshot["installUrl"])
    before = pin_file.read_bytes()
    current = json.loads(before)
    old = tuple(map(int, current["version"].split(".")))
    new = tuple(map(int, version.split(".")))
    if new < old:
        raise ValueError("Refusing a version downgrade")
    report = {"package": "retro-rewind-pack", "oldVersion": current["version"],
              "newVersion": version, "sourceUrl": ZIP.format(version),
              "changed": new != old, "applied": False}
    if new == old or not apply:
        return report
    fetched = json.loads(subprocess.check_output(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", ZIP.format(version)],
        text=True, timeout=1800,
    ))
    if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", fetched["hash"]):
        raise ValueError("Nix did not return a SHA256 SRI hash")
    proposed = {"version": version, "hash": fetched["hash"]}
    # An update must preserve concurrent manual work and leave no partial pin.
    if pin_file.read_bytes() != before:
        raise ValueError("Pin changed during discovery; refusing overwrite")
    temporary = pin_file.with_name(pin_file.name + ".update-tmp")
    with temporary.open("x") as output:
        output.write(json.dumps(proposed, indent=2) + "\n")
        output.flush()
        os.fsync(output.fileno())
    if pin_file.read_bytes() != before:
        temporary.unlink()
        raise ValueError("Pin changed before publication; refusing overwrite")
    temporary.replace(pin_file)
    return report | {"applied": True, "hash": fetched["hash"]}


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
