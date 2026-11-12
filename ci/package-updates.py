#!/usr/bin/env python3
"""Prepare data-only package pins; publish one preserved, reviewed routine PR."""
import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BRANCH = "automation/package-updates"
MARKER = "<!-- maintained-package-updates -->"
SHA = re.compile(r"[0-9a-f]{40}")
SRI = re.compile(r"sha256-[A-Za-z0-9+/]{43}=")
SEMVER = re.compile(r"\d+\.\d+\.\d+")
DATED = re.compile(r"0-unstable-\d{4}-\d{2}-\d{2}")
spec = importlib.util.spec_from_file_location("package_forge", ROOT / "ci/automation-forge.py")
forge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(forge)
channel = forge.channel


def git(*args, env=None):
    return channel.run("git", *args, env=env)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def configuration():
    policy = json.loads((ROOT / "ci/package-updates.json").read_text())
    rules = json.loads((ROOT / "ci/channels.json").read_text())
    if policy.get("version") != 1 or not policy.get("handlers"):
        raise ValueError("Missing package handler policy")
    if (rules.get("forge") != "github" or rules.get("repository") != "dweee/dave-packages"
            or rules.get("branch") != "main"
            or rules.get("remote") != "https://github.com/dweee/dave-packages.git"):
        raise ValueError("Unreviewed package publication destination")
    files = []
    for name, entry in policy["handlers"].items():
        if not re.fullmatch(r"[a-z][a-z0-9-]+", name):
            raise ValueError("Invalid package handler")
        for path in [entry["script"], *entry["files"]]:
            if not re.fullmatch(r"pkgs/[a-z0-9._/-]+[.][a-z]+", path) or ".." in path:
                raise ValueError("Invalid package updater path")
        files.extend(entry["files"])
    if len(files) != len(set(files)):
        raise ValueError("Handlers must have disjoint generated files")
    return policy, rules, set(files)


def normalized(path, content):
    """Allow data changes, never executable changes hidden in a routine pin PR."""
    if path == "pkgs/yaas/default.nix":
        text = content.decode()
        for name, valid in [("version", DATED), ("rev", SHA), ("hash", SRI), ("cargoHash", SRI)]:
            pattern = re.compile(r'\b' + name + r' = "([^"\n]+)";')
            found = list(pattern.finditer(text))
            if len(found) != 1 or not valid.fullmatch(found[0][1]):
                raise ValueError("Unrecognized generated YAAS pin")
            text = pattern.sub(name + ' = "<generated>";', text, count=1)
        return text
    value = json.loads(content)
    if path == "pkgs/yaas/pubspec.lock.json":
        if set(value) != {"packages", "sdks"} or not all(isinstance(v, dict) for v in value.values()):
            raise ValueError("Unexpected Flutter lock schema")
        return "<generated Flutter dependency lock>"
    if path == "pkgs/codexbar/cli-pin.json":
        if set(value) != {"version", "assets"} or not SEMVER.fullmatch(value["version"]):
            raise ValueError("Unexpected CodexBar pin schema")
        if set(value["assets"]) != {"x86_64-linux", "aarch64-linux"}:
            raise ValueError("Incomplete CodexBar native assets")
        for system, asset in value["assets"].items():
            arch = system.removesuffix("-linux")
            if (set(asset) != {"name", "hash"} or not SRI.fullmatch(asset["hash"])
                    or asset["name"] != f'CodexBarCLI-v{value["version"]}-linux-{arch}.tar.gz'):
                raise ValueError("Invalid CodexBar asset pin")
        return "<generated CodexBar pins>"
    if path == "pkgs/retro-rewind-pack/pin.json":
        if set(value) != {"version", "hash"} or not SEMVER.fullmatch(value["version"]) or not SRI.fullmatch(value["hash"]):
            raise ValueError("Unexpected Retro Rewind pin schema")
        return "<generated Retro Rewind pin>"
    if path == "pkgs/blackglass/pin.json":
        if (set(value) != {"version", "revision", "hash"} or not DATED.fullmatch(value["version"])
                or not SHA.fullmatch(value["revision"]) or not SRI.fullmatch(value["hash"])):
            raise ValueError("Unexpected Black Glass pin schema")
        return "<generated Black Glass pin>"
    if path == "pkgs/horizon/sources.json":
        if set(value) != {"launcher", "game", "bin", "mixins", "updated"}:
            raise ValueError("Unexpected Horizon pin schema")
        for group, channels in [("launcher", {"stable", "head"}), ("game", {"stable", "unstable", "head"})]:
            if set(value[group]) != channels:
                raise ValueError("Incomplete Horizon source channels")
        for pin in [*value["launcher"].values(), *value["game"].values(), value["mixins"]]:
            if (not {"version", "rev", "hash", "cargoHash"} <= set(pin)
                    or not set(pin) <= {"version", "rev", "hash", "cargoHash", "release", "nightly"}
                    or not SHA.fullmatch(pin["rev"]) or not SRI.fullmatch(pin["hash"])
                    or not SRI.fullmatch(pin["cargoHash"])):
                raise ValueError("Invalid Horizon source pin")
        if set(value["bin"]) != {"stable", "unstable", "launcher"}:
            raise ValueError("Unexpected Horizon binary channels")
        for label in ["stable", "unstable"]:
            entry = value["bin"][label]
            if set(entry) != {"version", "tag", "rev", "game", "server"} or not SHA.fullmatch(entry["rev"]):
                raise ValueError("Invalid Horizon binary channel")
        if set(value["bin"]["launcher"]) != {"version", "assets"}:
            raise ValueError("Invalid Horizon launcher assets")
        groups = [value["bin"]["launcher"]["assets"]]
        groups += [value["bin"][c][k] for c in ["stable", "unstable"] for k in ["game", "server"]]
        for assets in groups:
            if not set(assets) <= {"x86_64-linux", "aarch64-darwin", "x86_64-darwin"}:
                raise ValueError("Unsupported Horizon binary platform")
            for asset in assets.values():
                if (set(asset) != {"url", "hash"} or not SRI.fullmatch(asset["hash"])
                        or not re.fullmatch(r"https://github.com/horizon-rust/horizon/releases/download/[^/]+/horizon-[A-Za-z0-9_.-]+", asset["url"])):
                    raise ValueError("Invalid Horizon binary asset")
        return "<generated Horizon pins>"
    raise ValueError("Unclassified generated pin path")


def validate_change(path, old, new):
    if normalized(path, old) != normalized(path, new):
        raise ValueError("Preserving manual source edits in " + path)


def prepare(proposal, snapshots=None):
    policy, rules, allowed = configuration()
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Package preparation requires a clean checkout")
    base = git("rev-parse", "HEAD^{commit}")
    before = {name: (ROOT / name).read_bytes() for name in allowed}
    reports = {}
    with tempfile.TemporaryDirectory(prefix="package-discovery-") as directory:
        for name, entry in policy["handlers"].items():
            forge.phase("discover-" + name)
            snapshot = (snapshots or Path(directory)) / (name + ".json")
            script = [sys.executable, str(ROOT / entry["script"])]
            # Resolve once, then apply that exact snapshot. Discovery cannot chase
            # a moving upstream while coordinated hashes are being regenerated.
            if snapshots:
                if snapshot.is_symlink() or not snapshot.is_file():
                    raise ValueError("Missing frozen handler snapshot: " + name)
                subprocess.run([*script, "--snapshot", str(snapshot)], cwd=ROOT, check=True, timeout=1800)
            else:
                subprocess.run([*script, "--write-snapshot", str(snapshot)], cwd=ROOT, check=True, timeout=1800)
            result = subprocess.run([*script, "--snapshot", str(snapshot), "--apply"], cwd=ROOT,
                                    check=True, text=True, capture_output=True, timeout=3600)
            reports[name] = json.loads(result.stdout)
    changed = git("diff", "HEAD", "--no-renames", "--name-only").splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard").splitlines()
    if untracked or not set(changed) <= allowed:
        raise ValueError("Updater changed files outside its declared pin scope")
    files = {}
    for path in changed:
        candidate = ROOT / path
        if candidate.is_symlink() or not candidate.is_file():
            raise ValueError("Updater removed or replaced a pin file")
        new = candidate.read_bytes()
        if len(new) > 4 * 1024 * 1024:
            raise ValueError("Oversize generated pin file")
        validate_change(path, before[path], new)
        files[path] = {"oldSHA256": digest(before[path]), "newSHA256": digest(new),
                       "content": base64.b64encode(new).decode()}
    if git("rev-parse", "HEAD^{commit}") != base:
        raise ValueError("Source ref changed during package discovery")
    value = {"version": 1, "repository": rules["repository"], "base": base,
             "files": files, "reports": reports}
    proposal.write_text(json.dumps(value, indent=2) + "\n")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write("changed=" + str(bool(files)).lower() + "\n")
    return value


def open_prs(rules):
    result, seen, page = [], set(), 1
    while True:
        batch = forge.api(rules, "GET", f'/repos/{rules["repository"]}/pulls?state=open&per_page=100&page={page}')
        if not isinstance(batch, list) or any(item["number"] in seen for item in batch):
            raise ValueError("Incomplete open PR pagination")
        if len({item["number"] for item in batch}) != len(batch):
            raise ValueError("Repeated PR pagination")
        result.extend(batch)
        seen.update(item["number"] for item in batch)
        if len(batch) < 100:
            return result
        page += 1


def branch_is_generated(base, head, allowed):
    ancestor = git("merge-base", base, head)
    names = git("diff", "--no-renames", "--name-only", ancestor, head).splitlines()
    if not set(names) <= allowed:
        return False
    try:
        authors = git("log", base + ".." + head, "--format=%an <%ae>").splitlines()
        if any(author != "Package updater <package-updater@monke.fail>" for author in authors):
            return False
        for name in names:
            for revision in [ancestor, head]:
                if not git("ls-tree", revision, "--", name).startswith("100644 blob "):
                    return False
            old = subprocess.check_output(["git", "show", ancestor + ":" + name], cwd=ROOT)
            new = subprocess.check_output(["git", "show", head + ":" + name], cwd=ROOT)
            validate_change(name, old, new)
    except (ValueError, TypeError, KeyError, subprocess.CalledProcessError):
        return False
    return True


def checks_running(rules, head):
    prefix = "/repos/" + rules["repository"] + "/commits/" + head
    page = 1
    while True:
        result = forge.api(rules, "GET", prefix + f"/check-runs?per_page=100&page={page}")
        runs = result["check_runs"]
        if any(item.get("status") != "completed" for item in runs):
            return True
        if len(runs) < 100:
            break
        page += 1
    # The statuses endpoint is newest-first; only the newest state of each
    # context is effective. A failed context does not hide another pending one.
    seen, page = set(), 1
    while True:
        batch = forge.api(rules, "GET", prefix + f"/statuses?per_page=100&page={page}")
        for item in batch:
            if item["context"] not in seen:
                seen.add(item["context"])
                if item["state"] == "pending":
                    return True
        if len(batch) < 100:
            return False
        page += 1


def remote_head(rules, env):
    output = git("ls-remote", "--heads", rules["remote"], "refs/heads/" + BRANCH, env=env)
    if not output:
        return None
    fields = output.split()
    if len(fields) != 2 or not SHA.fullmatch(fields[0]) or fields[1] != "refs/heads/" + BRANCH:
        raise ValueError("Unexpected routine branch reference")
    return fields[0]


def publish(proposal):
    _, rules, allowed = configuration()
    if proposal.is_symlink() or proposal.stat().st_size > 16 * 1024 * 1024:
        raise ValueError("Invalid data-only package proposal")
    value = json.loads(proposal.read_text())
    base = git("rev-parse", "HEAD^{commit}")
    if (value.get("version") != 1 or value.get("repository") != rules["repository"]
            or value.get("base") != base or not SHA.fullmatch(base)
            or not isinstance(value.get("files"), dict) or not set(value["files"]) <= allowed):
        raise ValueError("Proposal differs from the trusted canonical checkout")
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Package publication requires a clean checkout")
    files = {}
    for path, entry in value["files"].items():
        old = (ROOT / path).read_bytes()
        new = base64.b64decode(entry["content"], validate=True)
        if len(new) > 4 * 1024 * 1024 or digest(old) != entry["oldSHA256"] or digest(new) != entry["newSHA256"]:
            raise ValueError("Package pin content hash mismatch")
        validate_change(path, old, new)
        files[path] = new
    if not files:
        print("All package pins are unchanged")
        return None
    prefix = "/repos/" + rules["repository"]
    canonical = forge.api(rules, "GET", prefix + "/branches/" + rules["branch"])["commit"]["sha"]
    if canonical != base:
        raise ValueError("Canonical base advanced; prepare a fresh proposal")
    prs = open_prs(rules)
    matching = [pr for pr in prs if pr.get("head", {}).get("ref") == BRANCH]
    if len(matching) > 1:
        raise ValueError("Preserving ambiguous routine PRs")
    current = matching[0] if matching else None
    if current and (MARKER not in (current.get("body") or "") or current["base"]["ref"] != rules["branch"]
                    or current["head"].get("repo", {}).get("full_name", "").lower() != rules["repository"].lower()):
        raise ValueError("Preserving a manually owned branch or PR")
    with tempfile.TemporaryDirectory(prefix="package-publish-") as directory:
        with channel.build_environment(dict(os.environ, CHANNEL_TOKEN=os.environ["AUTOMATION_TOKEN"])):
            env = channel.git_env(directory)
            head = remote_head(rules, env)
            if current and current["head"]["sha"] != head:
                raise ValueError("Routine PR head changed during verification")
            if head:
                git("fetch", "--no-tags", rules["remote"], "refs/heads/" + BRANCH, env=env)
                if not branch_is_generated(base, head, allowed):
                    raise ValueError("Preserving routine branch with manual source changes")
                if current and checks_running(rules, head):
                    print("Preserving the current routine PR while its checks execute")
                    return head
            for path, content in files.items():
                (ROOT / path).write_bytes(content)
            git("add", "--", *files)
            tree = git("write-tree")
            pushed = not head or git("rev-parse", head + "^{tree}") != tree
            if pushed:
                parents = ["-p", base]
                if head and git("merge-base", head, base) != head:
                    parents = ["-p", head, *parents]
                new_head = git("-c", "user.name=Package updater", "-c", "user.email=package-updater@monke.fail",
                               "commit-tree", tree, *parents, "-m", "Update maintained package source pins")
                if remote_head(rules, env) != head:
                    raise ValueError("Routine branch advanced; preserving concurrent work")
                # Like the maintained input publisher, retain the old head and
                # canonical base as parents. No force push or history rewrite.
                git("-c", "credential.helper=", "push", rules["remote"], new_head + ":refs/heads/" + BRANCH, env=env)
                head = new_head
    body = ("Deterministic package discovery and coordinated source/hash regeneration. "
            "Required native builds, independent review, cache verification and normal channel gates remain separate. "
            "No activation is performed.\n\n```json\n" + json.dumps(value.get("reports", {}), indent=2) + "\n```\n\n" + MARKER)
    if current:
        fresh = forge.api(rules, "GET", prefix + "/pulls/" + str(current["number"]))
        if fresh.get("state") != "open" or fresh["head"]["sha"] != head:
            raise ValueError("Routine PR changed after branch publication")
        if pushed:
            forge.api(rules, "POST", prefix + "/issues/" + str(current["number"]) + "/comments",
                      {"body": "Updated this routine PR in place at `" + head + "`; prior head and current canonical base are retained.\n\n" + body})
        forge.api(rules, "PATCH", prefix + "/pulls/" + str(current["number"]), {"body": body})
    else:
        current = forge.api(rules, "POST", prefix + "/pulls",
                            {"title": "Update maintained package sources", "head": BRANCH, "base": rules["branch"], "body": body})
    checks = dict(rules, inputCheckWorkflows=list(dict.fromkeys(
        [*rules.get("inputCheckWorkflows", []), "package-updates.yml"])))
    forge.dispatch_input_checks(checks, prefix, {"head": {"ref": BRANCH, "sha": head}})
    print(current.get("html_url", "Routine package PR updated"))
    return head


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["prepare", "publish"])
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--snapshots", type=Path, help="Reuse an already frozen target set for reproducible preparation")
    args = parser.parse_args()
    try:
        if args.action == "prepare":
            prepare(args.proposal, args.snapshots)
        else:
            if args.snapshots:
                raise ValueError("Snapshots apply only to preparation")
            publish(args.proposal)
    except Exception as error:
        print("Package update failed: " + forge.failure_detail(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
