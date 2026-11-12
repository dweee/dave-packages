#!/usr/bin/env python3
"""Isolated, network-free checks of installed Lightning and upstream contracts."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    binary = args.package / "bin/lightning-matrix"
    records = []
    with tempfile.TemporaryDirectory(prefix="lightning-native-check-") as directory:
        env = os.environ.copy()
        env.update(HOME=directory, QT_QPA_PLATFORM="offscreen", LANG="C.UTF-8")
        for key in ["XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR"]:
            path = Path(directory) / key.lower()
            path.mkdir(mode=0o700)
            env[key] = str(path)
        def run(name, argv, cwd=None):
            result = subprocess.run(argv, env=env, cwd=cwd, capture_output=True, text=True, timeout=120)
            records.append({"check": name, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
            if result.returncode:
                raise RuntimeError(name + " failed: " + result.stderr + result.stdout)
            return result.stdout
        version = run("version", [str(binary), "--version"])
        if "Lightning " + args.version not in version:
            raise RuntimeError("Installed binary version differs from source manifest")
        run("help", [str(binary), "--help"])
        run("image-format-status", [str(binary), "--image-format-status"])
        run("gstreamer-call-media-status", [str(binary), "--call-media-status"])
        run("spell-selftest", [str(binary), "--spell-selftest"])
        candidates = list((args.package / "bin").glob(".*-wrapped"))
        candidates += list((args.package / "Applications/Lightning.app/Contents/MacOS").glob(".*-wrapped"))
        executable = next((p for p in candidates if p.is_file()), binary)
        if sys.platform.startswith("linux"):
            links = run("dynamic-linkage", ["ldd", str(executable)])
            if "not found" in links or "libQt6Core" not in links:
                raise RuntimeError("Missing Qt or native shared library")
        elif sys.platform == "darwin":
            run("dynamic-linkage", ["otool", "-L", str(executable)])
        for name in ["camera_fixed_modes", "followup_app_sources", "followup_qml_contracts", "gui5c_regressions"]:
            run("upstream-contract-" + name,
                [sys.executable, "-B", str(args.source / f"tests/test_{name}.py"), "-v"], args.source)
    print(json.dumps({"version": args.version, "checks": records, "result": "PASS"}, indent=2))


if __name__ == "__main__":
    main()
