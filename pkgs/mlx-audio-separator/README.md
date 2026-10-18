# MLX audio separator on Rotna

Packages `mlx-audio-separator` 0.1.20 at
`2f55dca7441cf8b243f4937d28dfe3dc4d60a8d3`. This CLI is enabled for Rotna
through `users/d/stemlab.nix` and `homeModules.mlx-audio-separator`. It requires
Apple Silicon macOS; the packaged wheels require macOS 14 or newer. Lapwolf's
x86 Linux configuration leaves the module disabled.

Launch the retained build immediately:

```sh
~/.local/state/flakey-builds/mlx-audio-separator/bin/mlx-audio-separator \
  /path/to/song.wav \
  -m mel-roformer-zfturbo-vocals-v1-mlx \
  --output_format WAV --output_dir /path/to/new-stems
```

This published, preconverted MLX model produces Vocals and Instrumental.
Its weights download on first use; Rotna's validation has already cached it.
Use `--list_models` to inspect the catalog and `--help` for CLI options.

Build from the Flakey checkout with `nix build .#mlx-audio-separator` or run
with `nix run .#mlx-audio-separator -- ...`. A separately authorized normal
system switch adds the CLI to PATH. There is no GUI or service to start.
An external Home Manager configuration can import `module.nix` and enable
`programs.mlx-audio-separator`, with an explicit `package` when needed.

The package ships the base upstream runtime. Optional `convert`, `ane` and
`ane-convert` extras are not included. Models needing first-time conversion
from Torch, ONNX or Demucs checkpoints require those additional dependencies;
the upstream CLI's default checkpoint needs conversion. Use the explicit
preconverted model above with this package.

MLX and MLX Metal use paired 0.32.3 upstream wheels. Nixpkgs' source MLX
disables Metal, and its binary package at this pin is 0.32.0. The local Python
scope also provides mlx-audio-io 1.3.24 and mlx-spectro 0.9.10. It does not
change MLX for other programs. Wheel URLs and hashes are fixed in
`python-packages.nix`. Other Python dependencies use the existing Nixpkgs
pin without a new flake input or a mutable pip environment.

Models stay in `~/.cache/mlx-audio-separator/models`; `AUDIO_SEPARATOR_MODEL_DIR`
or `--model_file_dir` selects another location. Converted Demucs caches, when
provided separately, use `~/.cache/mlx-audio-separator/demucs` and
`MLX_AUDIO_SEPARATOR_DEMUCS_CACHE_DIR`. Models and generated audio are not
bundled in the Nix package.

Validated on Rotna on 2026-10-15: 47 selected offline CLI, catalog and cache
tests passed. Real Metal inference reported `Device(gpu, 0)` and produced
two 16-bit stereo 44.1 kHz WAVs from one second of synthetic audio. The
inference stage took about three seconds; this is a smoke test, not a music
quality or performance benchmark. Other architectures and optional
checkpoint conversion were not validated.
