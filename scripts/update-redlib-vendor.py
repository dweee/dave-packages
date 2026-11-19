#!/usr/bin/env python3
"""Check Redlib upstream or prepare a three-way merged, isolated review candidate."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

UPSTREAM = "https://github.com/redlib-org/redlib.git"


def run(*args, cwd=None, check=True):
    return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=check)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--candidate", type=Path, help="new output directory; never modifies vendor/redlib")
    parser.add_argument("--ref", default="HEAD", help="official upstream ref, resolved to an immutable commit")
    parser.add_argument("--check", action="store_true", help="read-only upstream comparison (default)")
    parser.add_argument("--build", action="store_true", help="regenerate Cargo hash and build candidate with Nix")
    parser.add_argument("--system", default="x86_64-linux")
    args = parser.parse_args()
    if args.check and args.candidate:
        parser.error("--check and --candidate are mutually exclusive")
    if args.build and not args.candidate:
        parser.error("--build requires --candidate")
    if not re.fullmatch(r"[a-z0-9_]+-[a-z0-9_]+", args.system):
        parser.error("invalid Nix system")
    root = args.root.resolve()
    metadata = (root / "vendor/redlib/VENDOR.md").read_text()
    base = re.search(r"Base commit: `([0-9a-f]{40})`", metadata)
    if not base:
        raise RuntimeError("VENDOR.md must record a full upstream base commit")
    base = base.group(1)
    refs = run("git", "ls-remote", UPSTREAM, args.ref, args.ref + "^{}").stdout.splitlines()
    direct = [line.split()[0] for line in refs if not line.split()[1].endswith("^{}")]
    peeled = [line.split()[0] for line in refs if line.split()[1].endswith("^{}")]
    if len(direct) != 1 or len(peeled) > 1:
        raise RuntimeError("upstream ref must resolve unambiguously via git ls-remote")
    target = (peeled or direct)[0]
    result = {"upstream": UPSTREAM, "base": base, "target": target,
              "status": "current" if base == target else "update-available"}
    if not args.candidate:
        print(json.dumps(result, indent=2))
        return 0
    output = args.candidate.resolve()
    if output.exists():
        raise RuntimeError("candidate directory already exists; refusing to overwrite")
    if output.is_relative_to(root / "vendor/redlib"):
        raise RuntimeError("candidate cannot be inside live vendor source")
    output.mkdir(parents=True)
    tree = output / "source"
    run("git", "clone", "--no-checkout", UPSTREAM, str(tree))
    run("git", "checkout", "--detach", base, cwd=tree)
    # Overlay the complete current source, including deletions, onto the upstream base.
    # Keep git metadata only. This captures every custom change rather than named paths.
    for path in tree.iterdir():
        if path.name != ".git":
            shutil.rmtree(path) if path.is_dir() and not path.is_symlink() else path.unlink()
    for path in (root / "vendor/redlib").iterdir():
        if path.name in (".git", "target"):
            continue
        destination = tree / path.name
        if path.is_dir() and not path.is_symlink():
            shutil.copytree(path, destination, symlinks=True)
        elif path.is_symlink():
            destination.symlink_to(path.readlink())
        else:
            shutil.copy2(path, destination)
    run("git", "add", "-f", ".", cwd=tree)
    run("git", "-c", "user.name=Redlib candidate", "-c", "user.email=candidate@localhost",
        "commit", "--allow-empty", "-m", "Preserve complete catalog vendored customization", cwd=tree)
    merge = run("git", "-c", "user.name=Redlib candidate", "-c", "user.email=candidate@localhost",
                "merge", "--no-commit", "--no-ff", target, cwd=tree, check=False)
    (output / "merge.log").write_text(merge.stdout + merge.stderr)
    result["conflicts"] = run("git", "diff", "--name-only", "--diff-filter=U", cwd=tree).stdout.splitlines()
    result["status"] = "conflicts" if merge.returncode else "candidate"
    if merge.returncode and not result["conflicts"]:
        raise RuntimeError("merge failed; inspect candidate merge.log")
    if not result["conflicts"]:
        vendor_note = tree / "VENDOR.md"
        vendor_note.write_text(re.sub(r"Base commit: `[^`]+`[^\n]*", f"Base commit: `{target}` (candidate)", vendor_note.read_text()))
    (output / "local-customizations.patch").write_text(run("git", "diff", base, "HEAD", cwd=tree).stdout)
    (output / "upstream.patch").write_text(run("git", "diff", base, target, cwd=tree).stdout)
    package = (root / "pkgs/redlib/default.nix").read_text()
    if package.count("src = ../../vendor/redlib;") != 1:
        raise RuntimeError("expected exactly one vendor source in Redlib package")
    package = package.replace("src = ../../vendor/redlib;", "src = builtins.toPath " + json.dumps(str(tree)) + ";")
    package_path = output / "package.nix"
    package_path.write_text(package)
    if args.build and not result["conflicts"]:
        expr = (f'let f = builtins.getFlake {json.dumps(str(root))}; p = f.inputs.nixpkgs.legacyPackages.{args.system}; '
                f'in p.callPackage {json.dumps(str(package_path))} {{}}')
        # Probe only cargoDeps; unrelated package failures cannot masquerade as hashes.
        probe = run("nix", "build", "--impure", "--no-link", "--expr",
                    f'({expr}).cargoDeps.overrideAttrs (_: {{ outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; }})', check=False)
        (output / "cargo-hash.log").write_text(probe.stdout + probe.stderr)
        hashes = re.findall(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", probe.stderr)
        if len(set(hashes)) != 1:
            result.update(status="failed", build="failed", error="Cargo hash regeneration failed; inspect cargo-hash.log")
            (output / "report.json").write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps(result, indent=2))
            return 1
        result["cargoHash"] = hashes[0]
        package_path.write_text(re.sub(r'cargoHash = "[^"]+";', f'cargoHash = "{hashes[0]}";', package))
        build = run("nix", "build", "--impure", "--no-link", "--expr", expr, check=False)
        (output / "build.log").write_text(build.stdout + build.stderr)
        result["build"] = "success" if build.returncode == 0 else "failed"
        if build.returncode:
            result["status"] = "failed"
    else:
        result["build"] = "skipped"
    (output / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return int(bool(result["conflicts"]) or result.get("build") == "failed")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Redlib updater failed: {error}", file=sys.stderr)
        sys.exit(1)
