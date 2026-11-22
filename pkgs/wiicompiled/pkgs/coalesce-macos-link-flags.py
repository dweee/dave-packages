#!/usr/bin/env python3
"""Rewrite MKW_NP_LINK_LIBRARIES so Darwin framework flags stay one CMake item.

Ninja emits `-Xlinker -weak_framework -Xlinker Name`. The harvest used to wrap
the bare Name as `-framework Name`, which becomes
`-Xlinker -weak_framework -Xlinker -framework Name`. Clang then passes
`-weak_framework` and `-framework` to ld, and ld errors with
`framework not found -framework`.
"""
from __future__ import annotations

import pathlib
import re
import sys

SET_RE = re.compile(
    r"set\(MKW_NP_LINK_LIBRARIES\n(.*?)\)\n",
    re.DOTALL,
)


def coalesce(items: list[str]) -> list[str]:
    out: list[str] = []
    index = 0
    count = len(items)
    while index < count:
        item = items[index]
        if item == "-Xlinker" and index + 1 < count and items[index + 1] in (
            "-weak_framework",
            "-framework",
        ):
            kind = items[index + 1]
            name_at = index + 2
            if name_at < count and items[name_at] == "-Xlinker":
                name_at += 1
            if name_at < count and items[name_at] == "-framework":
                name_at += 1
            if name_at >= count or items[name_at].startswith("-"):
                raise SystemExit(
                    f"coalesce-macos-link-flags: cannot parse framework after {items[index:index + 6]}"
                )
            out.append(f"-Wl,{kind},{items[name_at]}")
            index = name_at + 1
            continue
        if (
            item in ("-framework", "-weak_framework")
            and index + 1 < count
            and not items[index + 1].startswith("-")
        ):
            out.append(f"-Wl,{item},{items[index + 1]}")
            index += 2
            continue
        out.append(item)
        index += 1
    return out


def parse_quoted_items(body: str) -> list[str]:
    return re.findall(r'"((?:\\.|[^"\\])*)"', body)


def format_block(items: list[str]) -> str:
    if not items:
        return 'set(MKW_NP_LINK_LIBRARIES "")\n'
    lines = "\n".join(f'    "{item.replace(chr(34), r"\"")}"' for item in items)
    return f"set(MKW_NP_LINK_LIBRARIES\n{lines})\n"


def rewrite(text: str) -> str:
    match = SET_RE.search(text)
    if not match:
        raise SystemExit("coalesce-macos-link-flags: MKW_NP_LINK_LIBRARIES block not found")
    items = coalesce(parse_quoted_items(match.group(1)))
    return text[: match.start()] + format_block(items) + text[match.end() :]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: coalesce-macos-link-flags.py native_prebuilt.cmake")
    path = pathlib.Path(sys.argv[1])
    original = path.read_text()
    updated = rewrite(original)
    if updated == original:
        return
    path.write_text(updated)
    print("coalesce-macos-link-flags: rewrote MKW_NP_LINK_LIBRARIES", file=sys.stderr)


if __name__ == "__main__":
    main()
