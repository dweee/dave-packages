#!/usr/bin/env python3
"""Pin the newest GeoIP database release for each package that bundles one.

The GeoIP repositories keep only their newest releases (daijro/geoip-all-in-one
about three weekly ones, P3TERX/GeoLite.mmdb two daily ones), so an older pin
stops downloading soon after a new release. Each pin is a JSON file read by its
package; this rewrites it from the release's asset digest without downloading.

    python3 scripts/update-geoip.py          # write the new pins
    python3 scripts/update-geoip.py --check  # report only
"""
import argparse
import base64
import json
import os
from pathlib import Path
import sys
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
PINS = ["pkgs/byparr/geoip.json", "pkgs/trawl/geoip.json"]


def latest_release(repo):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "dave-packages-geoip-update"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    request = Request(f"https://api.github.com/repos/{repo}/releases/latest", headers=headers)
    with urlopen(request, timeout=45) as response:
        return json.load(response)


def pin_for(pin):
    release = latest_release(pin["repo"])
    asset = next((a for a in release["assets"] if a["name"] == pin["asset"]), None)
    if asset is None:
        raise SystemExit(f"{pin['repo']} {release['tag_name']} has no asset {pin['asset']}")
    algorithm, _, digest = (asset.get("digest") or "").partition(":")
    if algorithm != "sha256" or len(digest) != 64:
        raise SystemExit(f"{pin['repo']} {release['tag_name']}: {pin['asset']} has no sha256 digest")
    return {
        **pin,
        "release": release["tag_name"],
        "url": asset["browser_download_url"],
        "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="report new releases without writing")
    args = parser.parse_args()
    for name in PINS:
        path = ROOT / name
        current = json.loads(path.read_text())
        new = pin_for(current)
        if new == current:
            print(f"{name}: {current['release']} is current")
            continue
        print(f"update available {name}: {current['release']} -> {new['release']}")
        if not args.check:
            path.write_text(json.dumps(new, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
