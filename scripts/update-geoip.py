#!/usr/bin/env python3
"""Pin the newest GeoIP database release for each package that bundles one.

The GeoIP repositories keep only their newest releases (daijro/geoip-all-in-one
about three weekly ones, P3TERX/GeoLite.mmdb two daily ones), so an older pin
stops downloading soon after a new release. Each pin is a JSON file read by its
package; this rewrites it from the release's asset digest without downloading.

    python3 scripts/update-geoip.py          # write the new pins
    python3 scripts/update-geoip.py --check  # report only
    python3 scripts/update-geoip.py --write-snapshot /tmp/geoip.json
    python3 scripts/update-geoip.py --snapshot /tmp/geoip.json --apply
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import sys
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
PINS = ["pkgs/byparr/geoip.json", "pkgs/trawl/geoip.json"]
SOURCES = {
    PINS[0]: ("daijro/geoip-all-in-one", "geoip-aio-all.mmdb.zip"),
    PINS[1]: ("P3TERX/GeoLite.mmdb", "GeoLite2-City.mmdb"),
}


def latest_release(repo):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "dave-packages-geoip-update"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    request = Request(f"https://api.github.com/repos/{repo}/releases/latest", headers=headers)
    with urlopen(request, timeout=45) as response:
        return json.load(response)


def pin_for(pin, release=None):
    release = latest_release(pin["repo"]) if release is None else release
    tag = release["tag_name"]
    if release.get("draft") or release.get("prerelease") or not re.fullmatch(r"\d{4}\.\d{2}\.\d{2}", tag):
        raise ValueError("Expected a dated stable GeoIP release")
    assets = [a for a in release["assets"] if a["name"] == pin["asset"]]
    if len(assets) != 1:
        raise ValueError("Expected one selected GeoIP release asset")
    asset = assets[0]
    expected_url = f"https://github.com/{pin['repo']}/releases/download/{tag}/{pin['asset']}"
    if asset["browser_download_url"] != expected_url or asset.get("state") != "uploaded" or asset.get("size", 0) <= 0:
        raise ValueError("Unexpected GeoIP asset origin or upload state")
    algorithm, _, digest = (asset.get("digest") or "").partition(":")
    if algorithm != "sha256" or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Selected GeoIP asset has no SHA256 digest")
    return {
        **pin,
        "release": release["tag_name"],
        "url": asset["browser_download_url"],
        "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="report new releases without writing")
    snapshots = parser.add_mutually_exclusive_group()
    snapshots.add_argument("--write-snapshot", type=Path)
    snapshots.add_argument("--snapshot", type=Path)
    parser.add_argument("--apply", action="store_true", help="apply the frozen release selection")
    args = parser.parse_args()
    current = {name: json.loads((ROOT / name).read_text()) for name in PINS}
    for name, pin in current.items():
        if (pin["repo"], pin["asset"]) != SOURCES[name]:
            raise ValueError("Preserving changed GeoIP source policy")
    snapshot = (json.loads(args.snapshot.read_text()) if args.snapshot else
                {"version": 1, "releases": {pin["repo"]: latest_release(pin["repo"]) for pin in current.values()}})
    if snapshot.get("version") != 1 or set(snapshot.get("releases", {})) != {p[0] for p in SOURCES.values()}:
        raise ValueError("Incomplete frozen GeoIP release set")
    # Validate the complete target set before writing either generated pin.
    selected = {name: pin_for(pin, snapshot["releases"][pin["repo"]]) for name, pin in current.items()}
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps(snapshot, indent=2) + "\n")
    apply = not args.check and (args.apply or not (args.snapshot or args.write_snapshot))
    reports = {}
    for name in PINS:
        path = ROOT / name
        old, new = current[name], selected[name]
        reports[name] = {"oldRelease": old["release"], "newRelease": new["release"], "changed": old != new}
        if apply and old != new:
            path.write_text(json.dumps(new, indent=2) + "\n")
    print(json.dumps(reports, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
