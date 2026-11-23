#!/usr/bin/env python3
"""Rewrite translator-baked absolute workspace paths to $out.

generate-data-init and translate-mod emit .S files whose .incbin lines use
Path.GetFullPath of the build sandbox. shards.cmake does the same. After
cp -a into $out those sandbox directories are gone, so every text artifact
has to name the store path instead.
"""
from __future__ import annotations

import os
import pathlib
import re
import sys

TEXT_SUFFIXES = {
    ".S",
    ".s",
    ".cmake",
    ".cpp",
    ".cc",
    ".cxx",
    ".h",
    ".hpp",
    ".c",
    ".inc",
    ".json",
    ".txt",
    ".xml",
}

INCBIN = re.compile(r'(\.incbin\s+")([^"]+)(")')


def roots_from_env() -> list[str]:
    src = os.environ["src_root"]
    found = {src, os.path.abspath(src), os.path.realpath(src)}
    return sorted((item.rstrip("/") for item in found), key=len, reverse=True)


def relocate(path: str, out: str, src_roots: list[str]) -> str:
    normalized = path.replace("\\", "/")
    for old in src_roots:
        if normalized == old or normalized.startswith(old + "/"):
            return out + normalized[len(old) :]
    for marker in ("/generated/", "/build/"):
        index = normalized.find(marker)
        if index < 0:
            continue
        candidate = out + normalized[index:]
        if os.path.exists(candidate):
            return candidate
    return path


def rewrite_text(text: str, out: str, src_roots: list[str]) -> str:
    for old in src_roots:
        text = text.replace(old, out)

    def replace_incbin(match: re.Match[str]) -> str:
        relocated = relocate(match.group(2), out, src_roots)
        return f"{match.group(1)}{relocated}{match.group(3)}"

    return INCBIN.sub(replace_incbin, text)


def main() -> None:
    out = os.environ["out"].rstrip("/")
    src_roots = roots_from_env()
    rewritten = 0
    missing: list[str] = []
    sandbox_leftovers: list[str] = []

    for path in pathlib.Path(out).rglob("*"):
        if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
            continue
        try:
            original = path.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        updated = rewrite_text(original, out, src_roots)
        if updated != original:
            path.write_text(updated)
            rewritten += 1
            original = updated
        if path.suffix.lower() == ".s":
            for match in INCBIN.finditer(original):
                blob = match.group(2)
                if not os.path.exists(blob):
                    missing.append(f"{path}: {blob}")
        if "/nix/var/nix/builds/" in original:
            sandbox_leftovers.append(str(path))

    if missing:
        sys.stderr.write("rewrite-translated-paths: .incbin target missing:\n")
        sys.stderr.write("\n".join(missing[:20]) + "\n")
        raise SystemExit(1)
    if sandbox_leftovers:
        sys.stderr.write("rewrite-translated-paths: sandbox paths remain in:\n")
        sys.stderr.write("\n".join(sandbox_leftovers[:20]) + "\n")
        raise SystemExit(1)
    print(f"rewrite-translated-paths: rewrote {rewritten} file(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
