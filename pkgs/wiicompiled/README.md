# WiiCompiled packaging

The non-flake `wiicompiled` input fetches patchzyy/Wiicompiled with submodules.
The frozen upstream revision is `ffbde831317c2a3fc7841f53e7244db83f024ff2`;
its Aurora gitlink is `33067e34a17ca680eb961d9e0f3d48ddb22a7d7f`.
`portable-baseline.patch` selects reproducible CPU targets for the native
library and the runtime shipped with the setup programs.

The public catalog provides the setup and translator tools and the native
dependency bundle on x86-64 Linux, ARM Linux and Apple Silicon.
The unwrapped setup is also available on both Linux architectures.

Run `python3 pkgs/wiicompiled/update.py --check` for canonical-owner discovery,
or use `--write-snapshot FILE` followed by `--snapshot FILE --apply` in a clean
isolated checkout. This updates the input through maintained Nix input tooling;
it never imports a newer upstream release directly or edits recipes. Upstream
advances require review in the owning fork before its canonical channel moves.
The input handler inventory is in `ci/package-updates.json`; publication uses
`ci/automation-forge.py inputs`, which reuses the existing input-update PR and
preserves branch ancestry without force pushes. The data-only package handler
pipeline is separate from source-input updates.
