#!/usr/bin/env python3
"""Only the explicit cache-only inventory can enter credentialed native jobs."""
import argparse
import json
from pathlib import Path

RUNNERS = {"x86_64-linux": "ubuntu-24.04", "aarch64-linux": "ubuntu-24.04-arm",
           "aarch64-darwin": "macos-15"}

def matrix(selected="all"):
    inventory = json.loads((Path(__file__).resolve().parents[1] / "nix/cache-only-platforms.json").read_text())
    jobs = [{"system": system, "runner": RUNNERS[system], "package": name}
            for system, names in inventory.items() for name in names
            if selected == "all" or selected == name]
    if not jobs:
        raise ValueError("Package is not an approved cache-only target")
    return {"include": jobs}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", default="all")
    print(json.dumps(matrix(parser.parse_args().package), separators=(",", ":")))
