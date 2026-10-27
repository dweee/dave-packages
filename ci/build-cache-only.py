#!/usr/bin/env python3
"""Build and push in one trusted job; never export archives or publish build logs."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time

STORE = re.compile(r"/nix/store/[a-z0-9]{32}-[^/\s]+")
STORE_MASK = re.compile(r"/nix/store/[a-z0-9]{32}-[^ ]*")
DENIED = re.compile(r"wiicompiled|subnetter", re.I)
# Keyguard's Gradle cache has thousands of fixed-output fetches. One long-lived
# `nix build` held 10-14 GiB after realising them, so Linux runners ran out of
# memory before Gradle started. Realise them in short-lived processes, publish
# each stage so a later run can substitute it, then build only the package.
STAGED = {
    "keyguard": {
        "fetches": "keyguard-deps",
        "attributes": ["mitmCache", "jbr", "crypto", "gpgAgent", "instance", "io",
                       "libNative", "sshAgent", "zxcvbn"],
    },
}
FETCH_BATCH = 250

def resource_heartbeat():
    # Foreground stderr is what the job log keeps. A background shell's output
    # never arrived before the runner was killed.
    if os.environ.get("TARGET_PACKAGE") != "keyguard" or os.uname().sysname != "Linux":
        return

    def sample_command(args):
        try:
            return subprocess.run(args, capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            return None

    def sample():
        stamp = time.strftime("%H:%M:%S", time.gmtime())
        lines = [f"--- keyguard-resource {stamp} ---"]
        for args in (["free", "-h"], ["df", "-h", "/", "/mnt", "/nix", "/tmp"]):
            result = sample_command(args)
            if result is not None:
                lines.extend((result.stdout or "").splitlines())
        result = sample_command(["ps", "-eo", "pid,ppid,etimes,rss,args", "--sort=-rss"])
        if result is not None:
            # Command lines identify which nix subcommand holds memory; store
            # paths are masked so none reach the public log.
            lines.extend(STORE_MASK.sub("<store>", line)[:180]
                         for line in (result.stdout or "").splitlines()[:9])
        result = sample_command(["ps", "-eo", "pid", "--sort=-rss", "--no-headers"])
        if result is not None:
            for pid in (result.stdout or "").splitlines()[:3]:
                pid = pid.strip()
                if not pid:
                    continue
                try:
                    status = Path(f"/proc/{pid}/status").read_text()
                except OSError:
                    continue
                for entry in status.splitlines():
                    if entry.startswith("VmSwap:"):
                        lines.append(f"pid {pid} {entry.strip()}")
                        break
        result = sample_command(["sudo", "dmesg", "-T"])
        if result is not None:
            hits = [line for line in (result.stdout or "").splitlines()
                    if any(token in line for token in ("Out of memory", "Killed process", "oom-kill", "invoked oom-killer"))]
            lines.extend(hits[-8:])
        print("\n".join(lines), file=sys.stderr, flush=True)

    def loop():
        while True:
            sample()
            time.sleep(15)

    threading.Thread(target=loop, name="keyguard-resource", daemon=True).start()

def check(value):
    if isinstance(value, str):
        if DENIED.search(value):
            raise ValueError("On-prem-only input")
    elif isinstance(value, dict):
        for key, item in value.items():
            check(key)
            check(item)
    elif isinstance(value, list):
        for item in value:
            check(item)

def failure_class(blob):
    # Classify without copying compiler output, store paths or server responses
    # into the public log. The raw diagnostic is discarded with the temp file.
    if isinstance(blob, bytes):
        blob = blob.decode("utf-8", "replace")
    text = blob.lower()
    if "transferred a partial file" in text or "stream error in the http/2 framing layer" in text:
        return "attic-partial-nar"
    if "unable to download" in text:
        return "substitute-download-failed"
    if "cannot allocate memory" in text or "out of memory" in text:
        return "out-of-memory"
    if "hash mismatch" in text:
        return "hash-mismatch"
    if "builder for" in text and "failed" in text:
        return "builder-failed"
    return "build-or-publication-failed"

def quiet(args, env, *, stdout=None):
    # Even on failure, neither compiler logs, server responses nor store paths
    # enter the public job log. Temporary output is deleted, never uploaded.
    with tempfile.TemporaryFile() as diagnostic:
        result = subprocess.run(args, env=env, stdout=stdout if stdout is not None else subprocess.PIPE,
                                stderr=diagnostic, text=True)
        if result.returncode != 0:
            diagnostic.seek(0)
            kind = failure_class(diagnostic.read())
            error = subprocess.CalledProcessError(result.returncode, args)
            error.failure_class = kind
            raise error
        return result

def store_path(name):
    return name if name.startswith("/nix/store/") else "/nix/store/" + name

def fetch_batches(graph, parent):
    nodes = {store_path(key): drv for key, drv in graph.items()}
    matches = [drv for drv in nodes.values() if drv.get("name") == parent]
    if len(matches) != 1:
        raise ValueError("Missing staged dependency cache")
    inputs = matches[0].get("inputDrvs") or matches[0].get("inputs", {}).get("drvs") or {}
    fetches = sorted(path for path in map(store_path, inputs)
                     if path in nodes and any("hash" in output for output in nodes[path]["outputs"].values()))
    if not fetches or any(not STORE.fullmatch(p) or not p.endswith(".drv") for p in fetches):
        raise ValueError("Missing staged fetches")
    return [fetches[i:i + FETCH_BATCH] for i in range(0, len(fetches), FETCH_BATCH)]

def realise(installables, env, directory, flags):
    manifest = Path(directory) / "outputs.txt"
    with manifest.open("w") as outputs:
        quiet(["nix", "build", "--fallback", *installables, *flags, "--no-link", "--print-out-paths"],
              env, stdout=outputs)
    paths = manifest.read_text().splitlines()
    if not paths or any(not STORE.fullmatch(p) or p.endswith(".drv") for p in paths):
        raise ValueError("Invalid built output")
    return manifest, paths

def publish(root, client, manifest, paths, env):
    closure = quiet(["nix-store", "--query", "--requisites", *paths], env).stdout.splitlines()
    if not closure or any(not STORE.fullmatch(p) for p in closure):
        raise ValueError("Missing runtime closure")
    check(closure)
    publish_env = dict(os.environ, ATTIC_BIN=client + "/bin/attic",
                       ATTIC_ENDPOINT="https://attic.monke.fail", ATTIC_CACHE="flakey")
    with tempfile.TemporaryFile() as log:
        # The existing helper confines credentials to mode-0600 client
        # configuration and uploads roots plus their runtime closures.
        quiet([sys.executable, str(root / "ci/push-attic.py"), "--outputs", str(manifest)],
              publish_env, stdout=log)

def build(system, package):
    resource_heartbeat()
    root = Path(__file__).resolve().parents[1]
    inventory = json.loads((root / "nix/cache-only-platforms.json").read_text())
    if package not in inventory.get(system, []):
        raise ValueError("Not an approved cache-only target")
    env = {key: value for key, value in os.environ.items() if key != "ATTIC_TOKEN"}
    if quiet(["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"], env).stdout.strip() != system:
        raise ValueError("Native runner mismatch")
    target = f".#cacheOnlyPackages.{system}.{package}"
    flags = ["--no-update-lock-file", "--no-write-lock-file"]
    document = json.loads(quiet(["nix", "derivation", "show", "--recursive", target, *flags], env).stdout)
    graph = document.get("derivations", document) if isinstance(document, dict) else None
    if (not isinstance(graph, dict) or not graph or
            any(not isinstance(drv, dict) or not isinstance(drv.get("outputs"), dict)
                for drv in graph.values())):
        raise ValueError("Missing derivation graph")
    check(graph)
    client = quiet(["nix", "build", "--inputs-from", ".", "nixpkgs#attic-client", *flags,
                    "--no-link", "--print-out-paths", "--max-jobs", "0", "--builders", ""], env).stdout.strip()
    if not STORE.fullmatch(client):
        raise ValueError("Invalid client path")
    stages = STAGED.get(package) if system.endswith("-linux") else None
    with tempfile.TemporaryDirectory(prefix="flakey-cache-only-", dir=os.environ["RUNNER_TEMP"]) as directory:
        if stages:
            batches = fetch_batches(graph, stages["fetches"])
            for number, batch in enumerate(batches, 1):
                # Stage labels carry counts only, never store paths.
                print(f"Stage fetch batch {number}/{len(batches)} ({len(batch)} fetches)", flush=True)
                realise([drv + "^*" for drv in batch], env, directory, flags)
            for attribute in stages["attributes"]:
                print(f"Stage {attribute}", flush=True)
                publish(root, client, *realise([f"{target}.{attribute}^*"], env, directory, flags), env)
            print("Stage package", flush=True)
        publish(root, client, *realise([target + "^*"], env, directory, flags), env)

if __name__ == "__main__":
    try:
        build(os.environ["TARGET_SYSTEM"], os.environ["TARGET_PACKAGE"])
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        kind = getattr(error, "failure_class", None) or "build-or-publication-failed"
        print("Cache-only build/publication failed [" + kind + "]. No artifacts or diagnostic logs were published.", file=sys.stderr)
        sys.exit(1)
    print("Cache-only build and private cache publication succeeded.")
