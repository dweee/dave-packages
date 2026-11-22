# WiiCompiled packaging

The non-flake `wiicompiled` input fetches patchzyy/Wiicompiled with submodules.
The frozen upstream revision is `ffbde831317c2a3fc7841f53e7244db83f024ff2`;
its Aurora gitlink is `33067e34a17ca680eb961d9e0f3d48ddb22a7d7f`.
`portable-baseline.patch` selects reproducible CPU targets for the native
library and the runtime shipped with the setup programs.

The public catalog provides the setup and translator tools and the native
dependency bundle on x86-64 Linux, ARM Linux and Apple Silicon.
The unwrapped setup is also available on both Linux architectures.
When setting up a disc, pass your existing local extractor with
`--disc-tool-bin /path/to/nodtool` on Linux or `--nodtool /path/to/nodtool`
on macOS. The setup packages do not bundle or download a disc extractor.

Run `python3 pkgs/wiicompiled/update.py --check` for canonical-owner discovery,
or use `--write-snapshot FILE` followed by `--snapshot FILE --apply` in a clean
isolated checkout. This updates the input through maintained Nix input tooling;
it never imports a newer upstream release directly or edits recipes. Upstream
advances require review in the owning fork before its canonical channel moves.
The input handler inventory is in `ci/package-updates.json`; publication uses
`ci/automation-forge.py inputs`, which reuses the existing input-update PR and
preserves branch ancestry without force pushes. The data-only package handler
pipeline is separate from source-input updates.

## Local game build

Import the catalog overlay and override `pkgs.wiicompiled` with your own PAL
RMCP01 dump as `iso` and an existing nodtool-compatible package as
`discExtractor`. The NixOS, Home Manager and nix-darwin modules also accept
`programs.wiicompiled.isoHash` and `programs.wiicompiled.discExtractor` when
`enableGame` is set. The disc recipe checks the extracted PAL executable and
REL hashes before translation.

For Retro Rewind, supply both the pack and your local PAL Retro-WFC payload as
`retroRewind` and `retroWfcPayload`, or as module options
`retroRewind.packRoot` and `retroRewind.wfcPayload`. The payload recipe verifies
the stage-2 header and region. It reads the file you supply.

Build in a local Nix store with automatic cache uploads disabled. The
disc, translated code and baked game contain data derived from your dump and
are outside the flake's build and publication matrix. The disc extractor and
prebuilt setup AppImage are omitted from these recipes because the upstream
extractor contains embedded decryption keys.

Frozen VR consumers can use `lib.wiicompiled` with their own source and tool
inputs. Its `compat-vr` paths retain the native dependency and translator
recipes for that source layout.
