# Lightning

`pin.json` records the stable `Mizerd/lightning` release, exact source commit and
Nix source NAR hash. The wrapper imports that immutable source's Qt 6 recipe with
`builtins.fetchTree`; it adds system AWS-LC and portable Darwin app packaging.
It preserves the upstream Cargo lock, Rust backend, LTO settings and package test
policy. It does not import a separate upstream nixpkgs or require IFD.

The catalog exposes `lightning-matrix-client` on x86_64-linux, aarch64-linux and
aarch64-darwin. Each platform requires its own native build and runtime checks;
being listed in the public/channel inventory does not establish those results.
The native callers run `check.py` after building. This checks version/help,
image decoders, GStreamer call engines, Hunspell spelling, dynamic linkage and
four upstream Python contract suites in an isolated, network-free profile.
Upstream's full C++ GUI suite is not enabled by its package recipe.

The maintained `lightning` package-update handler resolves a stable release and
its peeled tag commit once, then generates the source NAR hash using Nix and
verifies the source's project version. It rejects a downgrade or retag. Use the
existing guarded publisher rather than opening a second routine branch:

```sh
python3 pkgs/lightning/update.py --write-snapshot /tmp/lightning.json
python3 ci/package-updates.py prepare --handler lightning \
  --snapshots /tmp/package-snapshots --proposal /tmp/package-update.json
```

For the second command, place the frozen snapshot at
`/tmp/package-snapshots/lightning.json`. Recipe changes belong in a reviewed
source PR; the routine publisher can change only `pin.json`.
