#!/usr/bin/env python3
"""Update both Linux CodexBar CLI assets from one frozen stable release."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPOSITORY = "steipete/CodexBar"
ARCHITECTURES = {"x86_64-linux": "x86_64", "aarch64-linux": "aarch64"}


def api(path):
    result = subprocess.run(["gh", "api", f"repos/{REPOSITORY}/{path}"], check=True,
                            capture_output=True, text=True, timeout=60)
    return json.loads(result.stdout)


def discover(tag=None):
    if tag is not None and not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Expected a stable vMAJOR.MINOR.PATCH tag")
    release = api("releases/" + ("tags/" + tag if tag else "latest"))
    tag = release["tag_name"]
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Release does not have a stable version tag")
    ref = api("git/ref/tags/" + tag)
    obj = ref["object"]
    peeled = None
    if obj["type"] == "tag":
        peeled = api("git/tags/" + obj["sha"])
        obj = peeled["object"]
    if obj["type"] != "commit" or not re.fullmatch(r"[0-9a-f]{40}", obj["sha"]):
        raise ValueError("Release tag does not resolve to one commit")
    return {"repository": REPOSITORY, "release": release, "tagRef": ref,
            "upstreamRevision": obj["sha"], "peeledTag": peeled}


def candidate(snapshot):
    if snapshot.get("repository") != REPOSITORY:
        raise ValueError("Unexpected release repository")
    release = snapshot["release"]
    tag = release["tag_name"]
    if release.get("draft") is not False or release.get("prerelease") is not False:
        raise ValueError("Only published stable releases are allowed")
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Expected a stable version tag")
    if snapshot["tagRef"]["ref"] != "refs/tags/" + tag:
        raise ValueError("Release and tag reference differ")
    if not re.fullmatch(r"[0-9a-f]{40}", snapshot["upstreamRevision"]):
        raise ValueError("Missing exact upstream revision")
    obj = snapshot["tagRef"]["object"]
    if obj["type"] == "tag":
        peeled = snapshot.get("peeledTag") or {}
        if peeled.get("sha") != obj["sha"] or peeled.get("tag") != tag:
            raise ValueError("Missing matching annotated tag object")
        obj = peeled["object"]
    if obj["type"] != "commit" or obj["sha"] != snapshot["upstreamRevision"]:
        raise ValueError("Upstream revision does not match the tag object")
    assets = {}
    selected = {}
    for system, arch in ARCHITECTURES.items():
        name = f"CodexBarCLI-{tag}-linux-{arch}.tar.gz"
        matches = [item for item in release["assets"] if item["name"] == name]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {system} CLI asset")
        asset = matches[0]
        url = f"https://github.com/{REPOSITORY}/releases/download/{tag}/{name}"
        if asset["browser_download_url"] != url or not isinstance(asset["id"], int):
            raise ValueError("Unexpected release asset identity or URL")
        digest = asset.get("digest", "")
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise ValueError("GitHub asset SHA256 is required")
        sri = "sha256-" + base64.b64encode(bytes.fromhex(digest.split(":")[1])).decode()
        assets[system] = {"name": name, "hash": sri}
        selected[system] = asset
    return {"version": tag[1:], "assets": assets}, selected


def update(pin_file, snapshot, apply=False):
    before = pin_file.read_bytes()
    current = json.loads(before)
    proposed, assets = candidate(snapshot)
    report = {"package": "codexbar-cli", "oldVersion": current["version"],
              "newVersion": proposed["version"], "upstreamRevision": snapshot["upstreamRevision"],
              "tag": snapshot["release"]["tag_name"], "changed": current != proposed,
              "applied": False, "verifiedAssets": []}
    old = tuple(map(int, current["version"].split(".")))
    new = tuple(map(int, proposed["version"].split(".")))
    if new < old:
        raise ValueError("Refusing a release downgrade")
    if new == old:
        if current != proposed:
            raise ValueError("Published assets for the installed version changed; refusing replacement")
        return report
    if not apply:
        return report
    # Fetch actual bytes through maintained Nix tooling before changing any pin.
    for system, asset in assets.items():
        output = subprocess.run(["nix", "store", "prefetch-file", "--json", "--name", asset["name"],
                                 asset["browser_download_url"]], check=True, capture_output=True,
                                text=True, timeout=600)
        fetched = json.loads(output.stdout)
        if fetched["hash"] != proposed["assets"][system]["hash"]:
            raise ValueError(f"Downloaded {system} asset does not match GitHub SHA256")
        report["verifiedAssets"].append({"system": system, "id": asset["id"],
                                         "hash": fetched["hash"], "storePath": fetched["storePath"]})
    if pin_file.read_bytes() != before:
        raise ValueError("Pin file changed during asset verification; preserving concurrent edit")
    data = json.dumps(proposed, indent=2) + "\n"
    temporary = pin_file.with_name(pin_file.name + ".update.tmp")
    temporary.write_text(data)
    os.replace(temporary, pin_file)
    report["applied"] = True
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pin-file", type=Path, default=Path("pkgs/codexbar/cli-pin.json"))
    parser.add_argument("--target", help="Resolve this exact stable tag rather than latest")
    parser.add_argument("--snapshot", type=Path, help="Reuse metadata captured by --write-snapshot")
    parser.add_argument("--write-snapshot", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.snapshot and args.target:
        parser.error("Choose a saved snapshot or a target tag")
    snapshot = json.loads(args.snapshot.read_text()) if args.snapshot else discover(args.target)
    candidate(snapshot)
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(json.dumps(update(args.pin_file, snapshot, args.apply), indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(f"CodexBar update failed before publication: {type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
