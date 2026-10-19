#!/usr/bin/env python3
"""Harvest aurora + third-party archives into MKW_NATIVE_PREBUILT_DIR layout.

Unix counterpart of launcher/Prepare-NativePrebuilt.ps1: configure runtime/ with
MKW_NATIVE_PREBUILT_EXPORT_DIR, build mkw_np_probe, then rewrite the probe-vs-control
Ninja command lines into native_prebuilt.cmake with @PKG@/@AURORA@/@RUNTIME@/@DEPS@
tokens. Shared-library harvest is optional (Linux/macOS vendor SDL statically).
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from collections import OrderedDict
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"harvest-native-prebuilt: {message}")


def unfold_ninja(text: str) -> str:
    return re.sub(r"\$\r?\n", "", text)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--export-dir", required=True, type=Path)
    parser.add_argument("--build-dir", required=True, type=Path)
    parser.add_argument("--aurora-dir", required=True, type=Path)
    parser.add_argument("--runtime-dir", required=True, type=Path)
    parser.add_argument("--deps-dir", required=True, type=Path)
    parser.add_argument("--package-dir", required=True, type=Path)
    return parser.parse_args()


def real(path: Path) -> Path:
    return path.resolve()


def read_meta(path: Path) -> dict[str, str]:
    meta: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        meta[key] = value
    return meta


def ninja_statement(lines: list[str], rule_prefix: str) -> dict[str, str]:
    """Match CMake Ninja rules exactly, or with a config suffix.

    CMake 4 writes ``CXX_COMPILER__mkw_np_probe_unscanned_Release``. A
    substring search for ``mkw_np_probe`` also hits ``mkw_np_probe_control``,
    which makes the probe-vs-control include diff empty.
    """
    prefix = "build "
    for index, line in enumerate(lines):
        if not line.startswith(prefix):
            continue
        colon = line.find(": ")
        if colon < 0:
            continue
        rule = line[colon + 2 :]
        space = rule.find(" ")
        if space >= 0:
            rule = rule[:space]
        if rule != rule_prefix and not rule.startswith(rule_prefix + "_"):
            continue
        if rule_prefix.endswith("mkw_np_probe") and "mkw_np_probe_control" in rule:
            continue
        variables: dict[str, str] = OrderedDict()
        for entry in lines[index + 1 :]:
            match = re.match(r"^  ([A-Z_]+) = ?(.*)$", entry)
            if not match:
                break
            variables[match.group(1)] = match.group(2)
        return variables
    fail(f"no Ninja statement whose rule is {rule_prefix!r} or {rule_prefix}_…")
    raise AssertionError


def split_ninja_list(value: str) -> list[str]:
    if not value.strip():
        return []
    return [item for item in value.split() if item]


def subtract_ordered(all_items: list[str], remove: list[str]) -> list[str]:
    pending = list(remove)
    result: list[str] = []
    for item in all_items:
        try:
            pending.remove(item)
        except ValueError:
            result.append(item)
    return result


def expand_rsp(items: list[str], build_dir: Path) -> list[str]:
    expanded: list[str] = []
    for item in items:
        rsp = None
        if item.startswith("-Wl,@"):
            rsp = item[len("-Wl,@") :]
        elif item.startswith("@"):
            rsp = item[1:]
        if rsp is None:
            expanded.append(item)
            continue
        path = Path(rsp)
        if not path.is_absolute():
            path = build_dir / path
        if not path.is_file():
            fail(f"response file missing: {path}")
        expanded.extend(split_ninja_list(path.read_text()))
    return expanded


def cmake_quote(value: str) -> str:
    return value.replace("\\", "/").replace('"', '\\"')


def format_cmake_block(name: str, items: list[str]) -> str:
    if not items:
        return f'set({name} "")\n'
    body = "\n".join(f'    "{cmake_quote(item)}"' for item in items)
    return f"set({name}\n{body})\n"


def starts_with_path(candidate: Path, root: Path) -> bool:
    try:
        candidate.relative_to(root)
        return True
    except ValueError:
        return False


def relative_to(candidate: Path, root: Path) -> str:
    return candidate.relative_to(root).as_posix()


def dep_maps(deps_dir: Path) -> list[tuple[Path, str]]:
    mapping: list[tuple[Path, str]] = []
    if not deps_dir.is_dir():
        return mapping
    for child in sorted(deps_dir.iterdir()):
        mapping.append((real(child), child.name))
    mapping.sort(key=lambda item: len(str(item[0])), reverse=True)
    return mapping


def convert_to_token(
    path: Path,
    kind: str,
    aurora: Path,
    runtime: Path,
    deps: Path,
    binary: Path,
    package: Path,
    generated_index: list[int],
    dep_prefixes: list[tuple[Path, str]],
) -> str:
    resolved = real(path) if path.exists() else path
    if starts_with_path(resolved, aurora):
        return f"@AURORA@/{relative_to(resolved, aurora)}"
    if starts_with_path(resolved, runtime):
        return f"@RUNTIME@/{relative_to(resolved, runtime)}"
    if starts_with_path(resolved, deps):
        return f"@DEPS@/{relative_to(resolved, deps)}"
    for prefix, name in dep_prefixes:
        if starts_with_path(resolved, prefix):
            rest = relative_to(resolved, prefix)
            return f"@DEPS@/{name}/{rest}" if rest != "." else f"@DEPS@/{name}"
    if starts_with_path(resolved, binary):
        if kind != "include":
            fail(f"unhandled build-tree artifact ({kind}): {resolved}")
        generated_index[0] += 1
        name = f"generated{generated_index[0]:02d}"
        destination = package / "include" / name
        destination.mkdir(parents=True, exist_ok=True)
        if path.is_dir():
            for child in path.iterdir():
                target = destination / child.name
                if child.is_dir():
                    shutil.copytree(child, target, dirs_exist_ok=True)
                else:
                    shutil.copy2(child, target)
        return f"@PKG@/include/{name}"
    fail(f"path escapes every shippable root ({kind}): {path}")
    raise AssertionError


def include_directories(arguments: list[str], convert) -> list[str]:
    directories: list[str] = []
    index = 0
    while index < len(arguments):
        entry = arguments[index]
        if entry.startswith("-I"):
            directories.append(convert(Path(entry[2:]), "include"))
        elif entry == "-isystem" and index + 1 < len(arguments):
            index += 1
            directories.append(convert(Path(arguments[index]), "include"))
        elif entry.startswith("-isystem"):
            directories.append(convert(Path(entry[len("-isystem") :]), "include"))
        elif entry == "-iframework" and index + 1 < len(arguments):
            index += 1
            directories.append(convert(Path(arguments[index]), "include"))
        else:
            fail(f"unexpected include argument: {entry}")
        index += 1
    return directories


def copy_harvested(source: Path, package: Path, subdirectory: str, copied: list[str]) -> str:
    name = source.name
    destination = package / subdirectory / name
    if destination.exists():
        fail(f"two harvested files collide on {name}: {source}")
    shutil.copy2(source, destination)
    relative = f"{subdirectory}/{name}"
    copied.append(relative)
    return relative


def main() -> None:
    args = parse_args()
    export = real(args.export_dir)
    build = real(args.build_dir)
    aurora = real(args.aurora_dir)
    runtime = real(args.runtime_dir)
    deps = real(args.deps_dir)
    package = real(args.package_dir)

    meta_path = export / "meta.txt"
    if not meta_path.is_file():
        fail(f"missing export metadata: {meta_path}")
    meta = read_meta(meta_path)

    ninja_path = build / "build.ninja"
    if not ninja_path.is_file():
        fail(f"missing build.ninja: {ninja_path}")
    lines = unfold_ninja(ninja_path.read_text()).splitlines()

    probe_compile = ninja_statement(lines, "CXX_COMPILER__mkw_np_probe")
    control_compile = ninja_statement(lines, "CXX_COMPILER__mkw_np_probe_control")
    probe_link = ninja_statement(lines, "CXX_EXECUTABLE_LINKER__mkw_np_probe")
    control_link = ninja_statement(lines, "CXX_EXECUTABLE_LINKER__mkw_np_probe_control")

    includes = subtract_ordered(
        split_ninja_list(probe_compile.get("INCLUDES", "")),
        split_ninja_list(control_compile.get("INCLUDES", "")),
    )
    defines = subtract_ordered(
        split_ninja_list(probe_compile.get("DEFINES", "")),
        split_ninja_list(control_compile.get("DEFINES", "")),
    )
    compile_options = subtract_ordered(
        split_ninja_list(probe_compile.get("FLAGS", "")),
        split_ninja_list(control_compile.get("FLAGS", "")),
    )
    link_items = expand_rsp(
        subtract_ordered(
            split_ninja_list(probe_link.get("LINK_LIBRARIES", "")),
            split_ninja_list(control_link.get("LINK_LIBRARIES", "")),
        ),
        build,
    )
    if not includes:
        fail("aurora compile interface is empty; the probe did not link aurora")
    if not link_items:
        fail("aurora link interface is empty; the probe did not link aurora")

    (package / "lib").mkdir(parents=True, exist_ok=True)
    (package / "bin").mkdir(parents=True, exist_ok=True)
    (package / "include").mkdir(parents=True, exist_ok=True)

    targets: dict[str, dict[str, str]] = {}
    targets_path = export / "targets.txt"
    if not targets_path.is_file():
        fail(f"missing {targets_path}")
    for line in targets_path.read_text().splitlines():
        if not line.strip():
            continue
        parts = line.split("|")
        if len(parts) != 4:
            fail(f"malformed exported target line: {line}")
        targets[parts[0]] = {
            "name": parts[0],
            "type": parts[1],
            "file": parts[2],
            "linker": parts[3],
        }

    dawn_linker = ""
    dawn_path = export / "dawn.txt"
    if dawn_path.is_file():
        for line in dawn_path.read_text().splitlines():
            if not line.strip():
                continue
            parts = line.split("|")
            if len(parts) >= 3:
                dawn_linker = parts[2]

    copied: list[str] = []
    linker_to_ref: dict[str, str] = {}
    shared_imports: list[tuple[str, str, str]] = []
    prefixes = dep_maps(deps)
    generated_index = [0]

    def convert(path: Path, kind: str) -> str:
        return convert_to_token(
            path,
            kind,
            aurora,
            runtime,
            deps,
            build,
            package,
            generated_index,
            prefixes,
        )

    for name in sorted(targets):
        target = targets[name]
        linker = Path(target["linker"])
        if not linker.is_file():
            continue
        linker_real = real(linker)
        if target["type"] == "SHARED_LIBRARY":
            runtime_file = Path(target["file"])
            if not runtime_file.is_file():
                fail(f"shared library {name} has no runtime file: {runtime_file}")
            relative_runtime = copy_harvested(runtime_file, package, "bin", copied)
            relative_linker = copy_harvested(linker, package, "lib", copied)
            imported = f"mkw_np::{name}"
            shared_imports.append((imported, relative_runtime, relative_linker))
            linker_to_ref[str(linker_real)] = imported
        else:
            relative_linker = copy_harvested(linker, package, "lib", copied)
            linker_to_ref[str(linker_real)] = f"@PKG@/{relative_linker}"

    if dawn_linker:
        dawn_linker_path = Path(dawn_linker)
        key = str(real(dawn_linker_path) if dawn_linker_path.exists() else dawn_linker_path)
        linker_to_ref[key] = "dawn::webgpu_dawn"

    cryptopp = package / "lib" / "libmkw_cryptopp.a"
    if not cryptopp.is_file():
        fail(f"harvested package is missing {cryptopp}")

    package_includes = include_directories(includes, convert)
    package_defines: list[str] = []
    for item in defines:
        if not item.startswith("-D"):
            fail(f"unexpected define argument: {item}")
        package_defines.append(item[2:].replace('\\"', '"'))

    package_link: list[str] = []
    previous_framework = False
    for item in link_items:
        if item == "-framework":
            package_link.append(item)
            previous_framework = True
            continue
        if previous_framework or item.startswith("-"):
            package_link.append(item)
            previous_framework = False
            continue
        previous_framework = False
        absolute = Path(item)
        if not absolute.is_absolute():
            absolute = build / item
        key = str(real(absolute) if absolute.exists() else absolute)
        if key in linker_to_ref:
            package_link.append(linker_to_ref[key])
            continue
        if absolute.exists():
            resolved = real(absolute)
            if starts_with_path(resolved, deps):
                package_link.append(f"@DEPS@/{relative_to(resolved, deps)}")
                continue
            for prefix, name in prefixes:
                if starts_with_path(resolved, prefix):
                    rest = relative_to(resolved, prefix)
                    token = f"@DEPS@/{name}/{rest}" if rest != "." else f"@DEPS@/{name}"
                    package_link.append(token)
                    break
            else:
                # SDK / system absolute paths stay absolute so the consumer
                # links the same tbd/dylib the harvest compiled against.
                package_link.append(resolved.as_posix())
            continue
        # Apple clang/Ninja records some SDK frameworks as a bare name.
        if sys.platform == "darwin" and "/" not in item and not item.startswith("-"):
            package_link.extend(["-framework", item])
            continue
        fail(f"link item is neither a flag nor a harvested archive: {item}")

    package_compile = [f"$<$<COMPILE_LANGUAGE:CXX>:{flag}>" for flag in compile_options]

    dawn_config = meta.get("dawn_config_dir", "")
    if not dawn_config:
        fail("export metadata is missing dawn_config_dir")
    dawn_token = convert(Path(dawn_config), "dawn")

    generated = [
        "# Generated by nix/pkgs/harvest-native-prebuilt.py - do not edit.",
        "#",
        "# Describes the precompiled aurora + third-party archives that replace a",
        "# from-source aurora-main build. Every path is a token resolved against the",
        "# consuming workspace, because the source trees still ship next to this",
        "# package and the runtime compiles against their headers.",
        "",
        "if(NOT MKW_NP_PACKAGE_DIR OR NOT MKW_NP_AURORA_DIR OR NOT MKW_NP_RUNTIME_DIR OR NOT MKW_NP_DEPS_DIR)",
        '    message(FATAL_ERROR "native_prebuilt.cmake must be included by runtime/cmake/NativePrebuilt.cmake")',
        "endif()",
        "",
        format_cmake_block("MKW_NP_INCLUDE_DIRECTORIES", package_includes).rstrip(),
        format_cmake_block("MKW_NP_COMPILE_DEFINITIONS", package_defines).rstrip(),
        format_cmake_block("MKW_NP_COMPILE_OPTIONS", package_compile).rstrip(),
        format_cmake_block("MKW_NP_LINK_LIBRARIES", package_link).rstrip(),
        format_cmake_block(
            "MKW_NP_AURORA_TARGETS",
            ["aurora::gx", "aurora::pad", "aurora::si", "aurora::vi", "aurora::mtx"],
        ).rstrip(),
        "",
        f'set(MKW_NP_DAWN_CONFIG_DIR "{cmake_quote(dawn_token)}")',
        f'set(MKW_NP_DAWN_VERSION "{cmake_quote(meta.get("aurora_dawn_version", ""))}")',
        "",
        "# Shared third-party libraries keep imported SHARED targets so that",
        "# $<TARGET_RUNTIME_DLLS> still copies them next to the game executable.",
    ]
    for imported, runtime_rel, implib_rel in shared_imports:
        generated.append(f"add_library({imported} SHARED IMPORTED GLOBAL)")
        generated.append(f"set_target_properties({imported} PROPERTIES")
        generated.append(f'    IMPORTED_LOCATION "${{MKW_NP_PACKAGE_DIR}}/{runtime_rel}"')
        generated.append(f'    IMPORTED_IMPLIB "${{MKW_NP_PACKAGE_DIR}}/{implib_rel}")')

    (package / "native_prebuilt.cmake").write_text("\n".join(generated) + "\n")
    print(
        f"harvest-native-prebuilt: {len(copied)} files, "
        f"{len(linker_to_ref)} linker refs, {len(shared_imports)} shared imports",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
