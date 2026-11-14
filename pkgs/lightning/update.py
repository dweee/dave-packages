#!/usr/bin/env python3
"""Pin a stable Lightning release and its exact public source NAR."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.request import Request, urlopen

REPOSITORY = "Mizerd/lightning"
SHA = re.compile(r"[0-9a-f]{40}")
SRI = re.compile(r"sha256-[A-Za-z0-9+/]{43}=")
SEMVER = re.compile(r"\d+\.\d+\.\d+")


def api(endpoint):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "dave-packages-lightning-update"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    with urlopen(Request("https://api.github.com/repos/" + REPOSITORY + endpoint, headers=headers), timeout=45) as response:
        return json.load(response)


def selection(snapshot):
    if snapshot.get("repository") != REPOSITORY or snapshot.get("version") != 1:
        raise ValueError("Unexpected Lightning source policy")
    release = snapshot["release"]
    tag = release["tag_name"]
    version = tag.removeprefix("v")
    if (not SEMVER.fullmatch(version) or release.get("draft") or release.get("prerelease")
            or release.get("html_url") != f"https://github.com/{REPOSITORY}/releases/tag/{tag}"):
        raise ValueError("Expected an official stable Lightning release")
    ref = snapshot["tagRef"]
    if ref.get("ref") != "refs/tags/" + tag:
        raise ValueError("Release and source tag differ")
    obj, seen = ref["object"], set()
    while obj["type"] == "tag":
        sha = obj["sha"]
        if not SHA.fullmatch(sha) or sha in seen or len(seen) >= 4:
            raise ValueError("Invalid annotated tag chain")
        seen.add(sha)
        tagged = snapshot["tagObjects"][sha]
        if tagged.get("sha") != sha:
            raise ValueError("Annotated tag identity mismatch")
        obj = tagged["object"]
    if obj["type"] != "commit" or not SHA.fullmatch(obj["sha"]):
        raise ValueError("Release tag must resolve to an immutable commit")
    return version, obj["sha"]


def discover():
    release = api("/releases/latest")
    tag = release["tag_name"]
    if not re.fullmatch(r"v?\d+\.\d+\.\d+", tag):
        raise ValueError("Expected a stable release tag")
    snapshot = {"version": 1, "repository": REPOSITORY, "release": release,
                "tagRef": api("/git/ref/tags/" + tag), "tagObjects": {}}
    obj = snapshot["tagRef"]["object"]
    while obj["type"] == "tag":
        sha = obj["sha"]
        if not SHA.fullmatch(sha) or sha in snapshot["tagObjects"] or len(snapshot["tagObjects"]) >= 4:
            raise ValueError("Invalid annotated release tag")
        tagged = api("/git/tags/" + sha)
        snapshot["tagObjects"][sha] = tagged
        obj = tagged["object"]
    selection(snapshot)
    return snapshot


def prefetch(revision, version):
    fetched = json.loads(subprocess.check_output([
        "nix", "flake", "prefetch", "--json", f"github:{REPOSITORY}/{revision}"
    ], text=True, timeout=600))
    locked = fetched["locked"]
    if (locked.get("type") != "github" or locked.get("owner") != "Mizerd"
            or locked.get("repo") != "lightning" or locked.get("rev") != revision
            or locked.get("narHash") != fetched.get("hash") or not SRI.fullmatch(fetched["hash"])):
        raise ValueError("Nix prefetch differs from the selected immutable source")
    source = Path(fetched["storePath"])
    cmake = (source / "CMakeLists.txt").read_text()[:256]
    found = re.search(r"project\s*\(\s*lightning\s+VERSION\s+(\d+\.\d+\.\d+)", cmake, re.I)
    if found is None or found[1] != version:
        raise ValueError("Release version and source CMake project disagree")
    return fetched["hash"]


def update(pin_file, snapshot, apply=False):
    version, revision = selection(snapshot)
    before = pin_file.read_bytes()
    current = json.loads(before)
    if (set(current) != {"version", "revision", "hash"} or not SEMVER.fullmatch(current["version"])
            or not SHA.fullmatch(current["revision"]) or not SRI.fullmatch(current["hash"])):
        raise ValueError("Preserving an unrecognized Lightning pin")
    if tuple(map(int, version.split("."))) < tuple(map(int, current["version"].split("."))):
        raise ValueError("Release downgrade requires review")
    if version == current["version"] and revision != current["revision"]:
        raise ValueError("Released tag moved; requires review")
    changed = (version, revision) != (current["version"], current["revision"])
    report = {"package": "lightning-matrix-client", "oldVersion": current["version"],
              "newVersion": version, "oldRevision": current["revision"], "newRevision": revision,
              "changed": changed, "applied": False}
    if not changed or not apply:
        return report
    proposed = {"version": version, "revision": revision, "hash": prefetch(revision, version)}
    if pin_file.read_bytes() != before:
        raise ValueError("Pin changed during source verification")
    temporary = pin_file.with_name(pin_file.name + ".update-tmp")
    with temporary.open("x") as output:
        output.write(json.dumps(proposed, indent=2) + "\n")
        output.flush()
        os.fsync(output.fileno())
    if pin_file.read_bytes() != before:
        temporary.unlink()
        raise ValueError("Pin changed before publication")
    temporary.replace(pin_file)
    return report | {"hash": proposed["hash"], "applied": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pin-file", type=Path, default=Path(__file__).with_name("pin.json"))
    sources = parser.add_mutually_exclusive_group()
    sources.add_argument("--snapshot", type=Path)
    sources.add_argument("--write-snapshot", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    snapshot = json.loads(args.snapshot.read_text()) if args.snapshot else discover()
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(json.dumps(update(args.pin_file, snapshot, args.apply), indent=2))


if __name__ == "__main__":
    main()
