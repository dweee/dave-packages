#!/usr/bin/env python3
"""Generate native package jobs from the collection's explicit platform inventory."""
import argparse
import json
from pathlib import Path

RUNNER_OVERRIDES = {
    ("aarch64-darwin", "pared"): "xcode-27",
}


def matrix(family, selected="all"):
    nix_dir = Path(__file__).resolve().parents[1] / "nix"
    inventory = json.loads((nix_dir / "platforms.json").read_text())
    forks = json.loads((nix_dir / "forks.json").read_text())
    build_only = json.loads((nix_dir / "build-only-packages.json").read_text())
    owners = {package: info["repository"] for info in forks.values() for package in info["packages"]}
    if selected in owners:
        raise ValueError("Package CI belongs to its application fork: " + owners[selected])
    inventory = {system: [package for package in packages if package not in owners]
                 for system, packages in inventory.items()}
    runners = {"aarch64-darwin": "macos-15", "x86_64-linux": "ubuntu-24.04",
               "aarch64-linux": "ubuntu-24.04-arm"}
    wanted = [system for system in inventory if (system.endswith("-darwin")) == (family == "darwin")]
    if selected != "all" and not any(selected in inventory[system] for system in wanted):
        raise ValueError("Selected package is unavailable for this workflow family")
    jobs = [{"system": system, "runner": RUNNER_OVERRIDES.get((system, package), runners[system]), "package": package}
            for system in wanted for package in inventory[system]
            if selected == "all" or package == selected]
    for job in jobs:
        if job["package"] in build_only.get(job["system"], []):
            job["build_only"] = True
    return {"include": jobs}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("family", choices=["darwin", "others"])
    parser.add_argument("--package", default="all")
    args = parser.parse_args()
    print(json.dumps(matrix(args.family, args.package), separators=(",", ":")))
