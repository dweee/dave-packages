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
DENIED = re.compile(r"wiicompiled|subnetter", re.I)
KEYGUARD_DEPENDENCY_BATCH_SIZE = 64

def resource_heartbeat():
    # Foreground stderr is what the job log keeps. A background shell's output
    # never arrived before the runner was killed.
    if os.environ.get("TARGET_PACKAGE") != "keyguard" or os.uname().sysname != "Linux":
        return

    def sample():
        stamp = time.strftime("%H:%M:%S", time.gmtime())
        lines = [f"--- keyguard-resource {stamp} ---"]
        for args, limit in (
            (["free", "-h"], None),
            (["df", "-h", "/", "/mnt", "/nix", "/tmp"], None),
            (["ps", "-eo", "pid,ppid,rss,vsz,etimes,comm", "--sort=-rss"], 8),
        ):
            try:
                result = subprocess.run(args, capture_output=True, text=True, timeout=5)
            except (OSError, subprocess.SubprocessError):
                continue
            chunk = (result.stdout or "").splitlines()
            lines.extend(chunk[:limit] if limit else chunk)
        try:
            result = subprocess.run(["sudo", "dmesg", "-T"], capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            result = None
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

def build_keyguard_dependency_inputs(target, graph, flags, env):
    cache_drv = quiet(
        ["nix", "eval", "--raw", f"{target}.mitmCache.drvPath", *flags], env
    ).stdout.strip()
    if not STORE.fullmatch(cache_drv):
        raise ValueError("Invalid Keyguard dependency-cache derivation")
    cache = graph.get(Path(cache_drv).name)
    if not isinstance(cache, dict):
        raise ValueError("Missing Keyguard dependency-cache derivation")
    inputs = cache.get("inputs", {})
    dependencies = inputs.get("drvs", {}) if isinstance(inputs, dict) else {}
    if not dependencies:
        dependencies = cache.get("inputDrvs", {})
    if not isinstance(dependencies, dict) or not dependencies:
        raise ValueError("Missing Keyguard dependency inputs")

    fixed_outputs = []
    for name in sorted(dependencies):
        derivation = graph.get(name)
        if not isinstance(derivation, dict) or not isinstance(derivation.get("outputs"), dict):
            raise ValueError("Invalid Keyguard dependency derivation")
        if any(
            isinstance(output, dict) and "hash" in output
            for output in derivation["outputs"].values()
        ):
            path = "/nix/store/" + name
            if not STORE.fullmatch(path):
                raise ValueError("Invalid Keyguard fixed-output derivation")
            fixed_outputs.append(path + "^*")
    if not fixed_outputs:
        raise ValueError("Missing Keyguard fixed-output dependencies")

    batches = [
        fixed_outputs[i : i + KEYGUARD_DEPENDENCY_BATCH_SIZE]
        for i in range(0, len(fixed_outputs), KEYGUARD_DEPENDENCY_BATCH_SIZE)
    ]
    print(
        f"Preparing {len(fixed_outputs)} Keyguard fixed-output dependencies "
        f"in {len(batches)} bounded Nix batches.",
        flush=True,
    )
    for index, batch in enumerate(batches, 1):
        print(
            f"Keyguard dependency batch {index}/{len(batches)} "
            f"({len(batch)} derivations).",
            flush=True,
        )
        quiet(["nix", "build", "--fallback", *batch, *flags, "--no-link"], env)
    quiet(["nix", "build", "--fallback", cache_drv + "^*", *flags, "--no-link"], env)

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
    if package == "keyguard" and system.endswith("-linux"):
        build_keyguard_dependency_inputs(target, graph, flags, env)
    client = quiet(["nix", "build", "--inputs-from", ".", "nixpkgs#attic-client", *flags,
                    "--no-link", "--print-out-paths", "--max-jobs", "0", "--builders", ""], env).stdout.strip()
    if not STORE.fullmatch(client):
        raise ValueError("Invalid client path")
    with tempfile.TemporaryDirectory(prefix="flakey-cache-only-", dir=os.environ["RUNNER_TEMP"]) as directory:
        manifest = Path(directory) / "outputs.txt"
        with manifest.open("w") as outputs:
            quiet(["nix", "build", "--fallback", target + "^*", *flags, "--no-link", "--print-out-paths"], env, stdout=outputs)
        paths = manifest.read_text().splitlines()
        if not paths or any(not STORE.fullmatch(p) or p.endswith(".drv") for p in paths):
            raise ValueError("Invalid built output")
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

if __name__ == "__main__":
    try:
        build(os.environ["TARGET_SYSTEM"], os.environ["TARGET_PACKAGE"])
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        kind = getattr(error, "failure_class", None) or "build-or-publication-failed"
        print("Cache-only build/publication failed [" + kind + "]. No artifacts or diagnostic logs were published.", file=sys.stderr)
        sys.exit(1)
    print("Cache-only build and private cache publication succeeded.")
