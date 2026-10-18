# StemLab

Packages the public StemLab source at
`a30f6f8ff85e5142c6374496efd0624443976ada`, providing the Qt GUI and
`stem-separate` CLI with audio-separator 0.47.0, PySide6 and FFmpeg. Supported
platforms are Apple Silicon macOS and x86_64 Linux. The package does not run
upstream's installer or create a pip environment.

StemLab is exposed through `cacheOnlyPackages`: its `diffq` dependency uses
CC-BY-NC-4.0, so it must not enter the public artifact workflows.

```sh
nix build .#cacheOnlyPackages.x86_64-linux.stemlab
./result/bin/stemlab
./result/bin/stem-separate balanced /path/to/input.wav /path/to/new-output
```

An external Home Manager configuration can import `module.nix`, enable
`programs.stemlab` and provide its package. macOS includes `StemLab.app`; Linux
includes a desktop application entry.

The Python scope uses released ONNX instead of `onnx-weekly` and nixpkgs versions
of beartype, rotary-embedding-torch and samplerate. Linux explicitly disables CUDA
and ROCm for the CPU backend; macOS retains upstream's automatic Apple MPS
selection. Build checks import the backend, including Demucs, and run offline
wrapper and Qt queue tests. Queue tests mock separation and do not establish
model quality, preview behavior or DAW drag-and-drop support. One fixture is
skipped on case-insensitive filesystems because it requires six distinct names.

Models download on first use into
`${XDG_CACHE_HOME:-$HOME/.cache}/808sgn-stem-lab/models`; `STEM_LAB_MODELS` selects
another cache. Weights and generated audio remain outside the Nix store.
`STEM_LAB_VENV` does not select the packaged backend. Use a new output directory
for CLI jobs: the GUI checks occupied destinations, while the CLI retains
upstream's output behavior.

Balanced and Fast are the upstream producer alpha's supported four-stem presets;
other presets remain experimental. Code is MIT, the `diffq` dependency is
CC-BY-NC-4.0, and model weights retain their own terms.
