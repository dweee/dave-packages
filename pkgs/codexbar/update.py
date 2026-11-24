#!/usr/bin/env python3
"""Update the CodexBar CLI source pin from one frozen stable release tag."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REPOSITORY = "steipete/CodexBar"
# Package.resolved alone determines the SwiftPM vendor hash; nixpkgs comes from this flake.
DEPS_EXPRESSION = '''
{ flake, rev, narHash }:
let
  pkgs = (builtins.getFlake flake).inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  src = builtins.fetchTree { type = "github"; owner = "steipete"; repo = "CodexBar"; inherit rev narHash; };
in pkgs.fetchSwiftPMDeps { name = "codexbar-cli-swiftpm-deps"; inherit src; hash = ""; }
'''


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
    return {"version": tag[1:], "revision": snapshot["upstreamRevision"]}


def source_hash(revision):
    output = subprocess.run(["nix", "flake", "prefetch", "--json", f"github:{REPOSITORY}/{revision}"],
                            check=True, capture_output=True, text=True, timeout=900)
    fetched = json.loads(output.stdout)
    if fetched.get("locked", {}).get("rev") != revision:
        raise ValueError("Prefetched source does not match the release revision")
    return fetched["hash"]


def swiftpm_deps_hash(revision, narHash):
    # A fixed-output build with an empty hash fails and reports the actual hash.
    with tempfile.TemporaryDirectory() as directory:
        expression = Path(directory) / "deps.nix"
        expression.write_text(DEPS_EXPRESSION)
        result = subprocess.run(["nix", "build", "--no-link", "--impure", "--file", str(expression),
                                 "--argstr", "flake", "path:" + os.getcwd(), "--argstr", "rev", revision,
                                 "--argstr", "narHash", narHash],
                                capture_output=True, text=True, timeout=1800)
    found = re.findall(r"got:\s+(sha256-[A-Za-z0-9+/]{43}=)", result.stderr)
    if result.returncode == 0 or len(found) != 1:
        raise ValueError("Could not determine the SwiftPM dependency hash")
    return found[0]


def update(pin_file, snapshot, apply=False):
    before = pin_file.read_bytes()
    current = json.loads(before)
    proposed = candidate(snapshot)
    report = {"package": "codexbar-cli", "oldVersion": current["version"],
              "newVersion": proposed["version"], "upstreamRevision": snapshot["upstreamRevision"],
              "tag": snapshot["release"]["tag_name"],
              "changed": {k: current.get(k) for k in proposed} != proposed, "applied": False}
    old = tuple(map(int, current["version"].split(".")))
    new = tuple(map(int, proposed["version"].split(".")))
    if new < old:
        raise ValueError("Refusing a release downgrade")
    if new == old:
        if current.get("revision") != proposed["revision"]:
            raise ValueError("The installed release tag moved; refusing replacement")
        return report
    if not apply:
        return report
    # Hash the source and its SwiftPM dependencies through Nix before changing any pin.
    proposed["hash"] = source_hash(proposed["revision"])
    proposed["swiftpmDepsHash"] = swiftpm_deps_hash(proposed["revision"], proposed["hash"])
    if pin_file.read_bytes() != before:
        raise ValueError("Pin file changed during hashing; preserving concurrent edit")
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
