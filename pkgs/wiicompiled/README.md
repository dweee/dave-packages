# WiiCompiled source ownership

The catalog imports `nix/overlay.nix` from the immutable, submodule-enabled
`wiicompiled` non-flake input. Source, recipes, GPL notices and bundled dependency
licenses belong to the public `dweee/Wiicompiled` fork's reviewed `flakey` branch.
The catalog uses its own locked nixpkgs; owner builds do not prove catalog builds.

Only translator, native-prebuilt, setup and Linux setup-unwrapped are public
roots. Nodtool is a transitive setup dependency, not a public root. No disc,
translation or game outputs are admitted here.

Run `python3 pkgs/wiicompiled/update.py --check` for canonical-owner discovery,
or use `--write-snapshot FILE` followed by `--snapshot FILE --apply` in a clean
isolated checkout. This updates the input through maintained Nix input tooling;
it never imports a newer upstream release directly or edits recipes. Upstream
advances require review in the owning fork before its canonical channel moves.
The input handler inventory is in `ci/package-updates.json`; publication uses
`ci/automation-forge.py inputs`, which reuses the existing input-update PR and
preserves branch ancestry without force pushes. The data-only package handler
pipeline is separate from source-input updates.
