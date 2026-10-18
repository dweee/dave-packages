# Kuna through headless Ghidra

`ghidra-kuna` composes the catalog's Ghidra with the source-built
`kuna_ghidra` backend from the public [Kuna packaging fork](https://github.com/dweee/kuna/tree/flakey).
It replaces the native decompiler in a separate Nix output: Ghidra's headless
analyzer does not load the Kuna GUI extension. This package is independent of
the optional `ghidra-mcp` GUI extension and Python bridge.

Build the CLI, plain REA, composed Ghidra and complete launcher with:

```sh
nix build .#kuna .#rea .#ghidra-kuna .#rea-kuna
```

For agent use, install `kuna` and `rea-kuna`. The launcher retains its private
Ghidra installation in its closure. Installing `ghidra-kuna` directly in a
profile also exposes `ghidra` and `ghidra-analyzeHeadless`, which can take
precedence over an existing GUI installation; use an isolated `nix shell` or
an explicit store executable when that is undesirable.

All three catalog platforms expose the packages. Source builds, headless
analysis and execution of recovered C have been verified on x86_64 Linux and
Apple Silicon macOS. ARM Linux remains subject to its native CI result. The
Ghidra/JDK and native decompiler must match the host architecture.

```sh
nix build .#checks.x86_64-linux.kuna-ghidra-headless
nix build .#checks.aarch64-darwin.kuna-ghidra-headless
```

The check imports a compiled fixture, verifies the `Kuna v` marker in recovered
functions, then compiles and executes the emitted C to check its behavior.
Relevant catalog CI jobs run it before exporting their runtime closures.

No listener or system service is needed. REA starts a local headless process
only when requested. See [the launcher notes](../rea-kuna/README.md) for MCP,
skills, backend selection and environment overrides.

Upstream [Kuna headless instructions](https://github.com/Noelo-Lab/kuna#ghidra-headless-usage)
describe the backend seam. REA packaging incorporates lessons from draft
[PR #4096](https://github.com/morluto/rea/pull/4096), including preserving runtime
PATH, testing native PTYs and retaining explicit backend settings.
