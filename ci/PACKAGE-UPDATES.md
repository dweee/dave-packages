# Maintained package updates

`package-updates.yml` runs every six hours and can be dispatched on `main`.
The read-only preparation job resolves each handler's upstream once, then
regenerates its exact pins from that frozen snapshot. It exports only a JSON
proposal containing the base commit, pin bytes, SHA256 hashes and results.

The separate publisher executes canonical automation code, checks the proposal
against its fresh base and declared generated-file scope, and maintains one
`automation/package-updates` PR. It preserves previous branch ancestry and the
current canonical base through ordinary forward-only pushes. Manual source or
pin commits, changed PR heads, active checks and ambiguous routine PRs stop an
update. It never force-pushes, closes another PR, enables auto-merge or changes
repository protections. Native build/check/cache/channel gates remain required.

Current package handlers:

- `codexbar-cli`: stable upstream release, both Linux architecture assets and
  their published digests. Each actual payload is hashed with Nix before pins
  change. The KDE plasmoid and nixpkgs Darwin application are separate owners.
- `retro-rewind-pack`: the official full-install pointer, an exact ZIP version
  and its Nix hash. This unfree payload uses `cacheOnlyPackages` and is excluded
  from the public artifact inventory.
- `yaas`: upstream `master`, exact source and nested Cargo hashes through
  `nix-update`, plus Flutter lock JSON generated from that same source with
  pinned `yq`. The mutable nightly release is not selected.
- `blackglass`: upstream `master` and a Git-verified source NAR hash. The
  package installs optional Plasma 6, Aurorae, Kvantum, SDDM and wallpaper
  assets into their proper data directories; it does not select a theme.

For a reproducible local preparation on a clean owning-repository checkout:

```sh
nix develop .#package-updates --command python3 ci/package-updates.py prepare \
  --proposal /tmp/package-update-proposal.json
```

Each handler supports `--write-snapshot FILE`, `--snapshot FILE` and `--apply`.
Reuse a directory of `<handler-name>.json` snapshots with `prepare --snapshots`
to validate or resume a frozen target set. Discovery does not require a write
token. Publication uses the existing repository-scoped automation identity,
with credentials confined to temporary Git configuration. Preparation never
receives that write identity, and the publisher never evaluates candidate Nix
or executes candidate package code.

Source changes and handler implementations belong in ordinary reviewed source
PRs. The routine branch accepts only the explicitly classified generated pin
files, not helper edits, workflows or application patches.
