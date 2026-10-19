# Keyguard packaging

This is the vendored Keyguard 3.2.3 package based on
[Nixpkgs PR #495316](https://github.com/NixOS/nixpkgs/pull/495316), with Linux and
macOS packaging. The package is exposed as `packages.<system>.keyguard`:

```sh
nix build .#keyguard
./result/bin/Keyguard
```

On macOS, the application bundle is `result/Applications/Keyguard.app`. Building
does not install the application or activate a system/Home Manager generation.
The current Nixpkgs pin supports Apple Silicon macOS; it has dropped Intel
macOS support. Intel SDK hashes and platform-specific dependency entries are
retained for a future port to a Nixpkgs branch that supports that platform.

## Upstream conventions

The package follows upstream's
[macOS release workflow](https://github.com/AChep/keyguard-app/blob/r20260916/.github/workflows/new_tag_release.yaml):
JetBrains Runtime 21, the `:desktopApp:createReleaseDistributable` task, native
Rust helpers, and Compose's `Keyguard.app` layout. Upstream requires JBR for
[AWT fixes](https://github.com/AChep/keyguard-app/commit/e0627190abfd94d9367dec42c39c991d378c3660).
Nixpkgs currently builds JBR from source only on Linux, so `jbr-darwin.nix`
pins the official macOS JBR SDK archives and preserves their bundle layout
and signatures. Application code and all seven native helper packages are
built from source. The app image uses local/ad-hoc signing; this package does
not require an Apple Developer certificate or produce a notarized DMG. After
Nix normalizes the jars, the runtime and app bundles are re-sealed with native
macOS `codesign`, preserving upstream's entitlements and hardened-runtime flags.
A strict recursive signature check is part of the Darwin fixup phase.

Nix builds the helpers separately, then stages them in upstream's
`app-resources/<platform>-<architecture>` directories before Compose runs.
Only the Gradle dependency on upstream's native-resource build is removed;
upstream's executable permission repair and verification remain enabled.
The previous patch that removed those checks is no longer needed. Linux
retains its desktop integration and JDK-8312488 launcher-crash backport.

The Gradle dependency cache follows the
[Nixpkgs Gradle guidance](https://nixos.org/manual/nixpkgs/unstable/#gradle),
including `__darwinAllowLocalNetworking` for its sandboxed loopback proxy and
`pkg = finalAttrs.finalPackage` for the downstream update script. During cache
updates, all Linux/macOS x64/arm64 Compose runtimes are added explicitly.
`postGradleUpdate` resolves them without changing the host JVM's OS or CPU and
re-records the pinned toolchain archives to retain other hosts' dependencies.
When upgrading Keyguard or Kotlin, refresh and validate on Linux and macOS.
The cache also includes the macOS Kotlin/Native toolchain and its LLVM download,
which upstream metadata tasks require even for the JVM desktop target. Normal
builds select only their own platform and keep Kotlin/Native state in the build
temporary directory. On macOS, the pinned LLVM/libffi archives seed its local
download cache because that downloader does not use Gradle's replay proxy.
Kotlin/Native performs its usual extraction. Rust dependencies remain pinned by their Cargo vendor hashes.

Refresh the cache from this repository with:

```sh
nix build .#keyguard.mitmCache.updateScript -o result-keyguard-deps
./result-keyguard-deps
```

## Verification and upstreaming

After building, use upstream's package verifier from the pinned source:

```sh
nix build .#keyguard.src -o result-keyguard-source
python3 result-keyguard-source/scripts/verify_native_bundle.py desktop result \
  --platform macos --arch aarch64 --launcher result/bin/Keyguard
```

The verifier checks native architectures, exported ABIs, crypto hardening,
packaged dependencies and executable helpers, then launches the packaged
application's isolated native smoke mode. That mode exercises crypto, file I/O,
password strength, single-instance coordination, the native desktop bridge,
SSH/GPG helpers and TLS initialization without opening a vault. The pre-existing
instance-test skips for sandbox ownership checks are retained; the packaged
coordination smoke test runs outside the build sandbox.

Validation with the repository pin on 2026-09-30:

- Full sandboxed source build on `aarch64-darwin`.
- Enabled Rust tests for all seven helper packages passed, with the existing
  instance sandbox skips described above.
- Upstream bundle architecture, ABI, crypto hardening and dependency-policy
  checks passed; all eight packaged native smoke markers passed through the
  installed CLI wrapper.
- Strict recursive macOS bundle signature verification passed after fixup and
  again on the final store output.
- Dependency-update script generation and replay of all four pinned native
  toolchain archives passed.

The final package evaluates on `aarch64-linux` and `x86_64-linux`; Linux builds
and runtime tests were not repeated for this change.

For a Nixpkgs contribution, carry the package/helper changes and dependency
cache into its existing Keyguard directory. The flakey-specific overlay and
flake package export are integration changes for this repository. Discuss the
macOS binary JBR SDK fallback with the JBR/Keyguard maintainers; a Darwin
source-build implementation of JBR would allow removing that fallback. Keep
the existing Linux launcher fix until the packaged JDK carries JDK-8312488.
