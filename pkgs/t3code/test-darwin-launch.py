#!/usr/bin/env python3
"""Smoke-test a native T3 bundle after Home Manager's copyApps operation.

Run on an interactive macOS desktop:
  python3 pkgs/t3code/test-darwin-launch.py /nix/store/...-t3code-darwin-...
The test uses a disposable T3 home; it never opens the user's database.
"""

import argparse
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def events(home):
    log = home / "userdata/logs/desktop.trace.ndjson"
    names = set()
    if log.exists():
        for line in log.read_text().splitlines():
            try:
                span = json.loads(line)
            except json.JSONDecodeError:
                continue  # The writer may still be appending the last record.
            names.update(event["name"] for event in span.get("events", []))
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--timeout", type=float, default=30)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="t3code-copyapps-") as directory:
        root = Path(directory)
        copied = root / "Home Manager Apps"
        # Match modules/targets/darwin/copyapps.nix, including unsafe-link
        # dereferencing and omission of timestamps (macOS signature handling).
        subprocess.run([
            "rsync", "--recursive", "--checksum", "--perms", "--links",
            "--copy-unsafe-links", "--specials", "--delete", "--chmod=+w",
            str(args.package.resolve() / "Applications") + "/", str(copied),
        ], check=True)
        app = copied / "T3 Code.app"
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", str(app)], check=True)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        home = root / "home"
        env = os.environ.copy()
        for name in ["ELECTRON_RUN_AS_NODE", "NODE_OPTIONS", "NODE_PATH", "VITE_DEV_SERVER_URL"]:
            env.pop(name, None)
        env.update(T3CODE_HOME=str(home), T3CODE_PORT=str(port))
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with (root / "launch.log").open("w") as output:
            process = subprocess.Popen(
                [str(app / "Contents/MacOS/T3 Code")], env=env,
                stdout=output, stderr=output, start_new_session=True,
            )
            try:
                deadline = time.monotonic() + args.timeout
                ready_since = None
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError(f"Copied app exited with {process.returncode}")
                    ready = False
                    try:
                        with http.open(f"http://127.0.0.1:{port}/", timeout=0.5) as response:
                            ready = response.status == 200 and b"<html" in response.read().lower()
                    except (OSError, urllib.error.URLError):
                        pass
                    if ready and "main window created" in events(home):
                        ready_since = ready_since or time.monotonic()
                        if time.monotonic() - ready_since >= 2:
                            print("PASS: copied app signature, backend HTTP 200, main window, stable startup")
                            return
                    else:
                        ready_since = None
                    time.sleep(0.2)
                raise RuntimeError("Copied app never reached stable backend and main-window readiness")
            finally:
                # Only this isolated app and its children belong to this group.
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)


if __name__ == "__main__":
    main()
