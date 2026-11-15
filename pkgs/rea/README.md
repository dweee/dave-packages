# REA for Nix

This expression builds [morluto/rea](https://github.com/morluto/rea) 6.7.0 from
revision `b0b485abff802b79d238dd24a9fa4abd0713d3ee`, including its TypeScript
runtime and matching generated agent skill. It uses this repository's nixpkgs
Node.js 24 and a fixed npm dependency closure.

Use the package through the repository overlay or `pkgs.callPackage ./pkgs/rea {}`.
It supports NixOS and nix-darwin as an ordinary user package; no system service is
needed. Register the absolute Nix executable with each agent's MCP configuration:

```json
{
  "mcpServers": {
    "rea": {
      "command": "/path/to/rea/bin/rea",
      "args": ["mcp"]
    }
  }
}
```

Install the complete `share/rea/skills/reverse-engineer-anything` directory into
the client's skill search path. It includes the referenced workflow documents.
The authored upstream skill alone neither registers the MCP server nor installs
analysis engines. Agents must reconnect after changing their registration.
Do not run `rea setup` or `rea update` to manage this Nix installation: keep
packages, skills and MCP registrations declarative.

REA's installer-ownership diagnostics currently classify symlinked Nix skills
as `unmanaged` and the composed `rea-kuna` launcher as a `stale` registration
because it differs from REA's direct dispatcher path. Those checks do not launch
the registered MCP or read the linked skill to validate it. Do not run setup to
replace these managed paths. `rea doctor --provider ghidra` checks the configured
engine independently; the package install check and
`nix build .#checks.x86_64-linux.rea-ghidra-headless` exercise the actual MCP,
native helpers, and decompiled code. Clients discover the version-matched linked
skills normally.

## Backends and limits

- Static JavaScript/Electron analysis needs no proprietary analysis engine.
- Native decompilation requires a separate engine. Upstream accepts Ghidra
  12.1.x and its matching host-native decompiler, with a full JDK 21 or newer.
  This repository's nixpkgs currently provides Ghidra 12.1.4. Set
  `GHIDRA_INSTALL_DIR` to its installation root, `JAVA_HOME` to the JDK, and
  optionally `REA_ANALYSIS_PROVIDER=ghidra` in the MCP environment. REA may also
  discover Ghidra through a launcher on PATH.
- The NixOS patch admits `ID=nixos` for host diagnostics. It does not enable
  upstream's deb/rpm/pacman Hopper installer. Hopper and IDA remain separately
  licensed, externally supplied software.
- The Linux wrapper includes procps and util-linux for process ownership and
  resource controls. It does not disable upstream ownership checks.
- Optional Frida is excluded because its npm installer downloads an additional
  native runtime outside the dependency lock. Frida instrumentation is unavailable
  in this build. Other native npm helpers are patched for the Nix runtime.
- The package supplies the caller tools for Android (jadx-headless-mcp 0.7.1
  JAR, full JDK 21 and ADB), ILSpy, GNU objdump, Rizin and WABT 1.0.42.
  Apktool is included on Linux x64 and Apple Silicon, where nixpkgs supplies
  its aapt dependency.
  On Linux it also supplies GDB, Binwalk 3.1.0, Unblob 26.6.4, Wireshark CLI,
  sigrok-cli 0.7.2 with libsigrokdecode, and mitmdump 12.2.3. On Linux x64 an
  isolated Python supplies pwntools 4.15.0, pyelftools 0.33 and Unicorn 2.1.2.
  `runtime-tools.nix` records the paths and strict-version overrides. Explicit
  caller settings take precedence. All CLI aliases, direct dispatcher and MCP
  inherit the same defaults, including absolute Nix prlimit paths for bounded
  EVM, firmware, JavaScript, signal and packet operations.
- On Darwin the package supplies the Swift compiler and macOS SDK needed by
  REA's owned-process token reader; no ambient Xcode installation is required.
- Browser/Electron runtime observation still requires an explicitly selected
  browser or target application. ADB operations need a reachable device, its
  authorization and host USB permissions. Installing ADB does not start a daemon.
- Wakaru source recovery and the optional pwndbg core-context supplement remain
  externally supplied. There are no compatible packages in the pinned nixpkgs;
  pwntools core/layout inspection works independently. Hopper, IDA and JEB need
  separately supplied licensed engines. Frida remains excluded as described
  above. These are explicit limits, not capabilities established by a handshake.

REA's own code is MIT licensed. Its retained third-party notices apply to bundled
material; independent engines retain their own licenses.

Packaging follows the process-wrapper, updater-layout and native-PTY findings in
[upstream draft Nix support PR #4096](https://github.com/morluto/rea/pull/4096).
The install check exercises both CLI aliases, the direct dispatcher, MCP
`initialize`/`tools/list`, native PTY creation, caller overrides, the full Java
compiler module, real Android class search and method decompilation against
upstream's hashed Appium ApiDemos APK, Apktool and Linux packet client discovery,
with no ambient PATH tools. The APK is inspected statically and never run.

Validated on x86_64 NixOS and aarch64-darwin: source build and install checks pass, the server lists
207 MCP tools, and the generated skill contains all seven workflow/reference
files. A static JavaScript fixture recovered its exported function with hashed
Evidence. A separate Ghidra 12.1.4/JDK 21 run analyzed the local coreutils ELF and
returned 34 segments, 2,987 procedures and 6,899 strings. On arm64 macOS, the
headless Kuna integration recovered C that compiled and passed execution checks;
the REA CLI also returned the Kuna version marker and the expected function body.
Darwin uses a binary Node interpreter wrapper because macOS rejects a script as
another script's shebang interpreter. Other declared host architectures have not
been built here.
