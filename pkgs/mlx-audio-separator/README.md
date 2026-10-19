# MLX audio separator

Packages `mlx-audio-separator` 0.1.20 at
`2f55dca7441cf8b243f4937d28dfe3dc4d60a8d3` for Apple Silicon macOS 14 or newer.
The package provides the upstream CLI; it does not start a service or GUI.

```sh
nix build .#mlx-audio-separator
./result/bin/mlx-audio-separator /path/to/song.wav \
  -m mel-roformer-zfturbo-vocals-v1-mlx \
  --output_format WAV --output_dir /path/to/new-stems
```

This preconverted model produces Vocals and Instrumental and downloads weights
on first use. `--list_models` lists the catalog; `--help` describes CLI options.
An external Home Manager configuration can import `module.nix`, enable
`programs.mlx-audio-separator` and provide its package.

The base runtime excludes optional `convert`, `ane` and `ane-convert` extras.
Checkpoints requiring Torch, ONNX or Demucs conversion need additional
dependencies. The example selects a preconverted model explicitly.

MLX and MLX Metal use paired 0.32.3 wheels. The private Python scope also supplies
mlx-audio-io 1.3.24 and mlx-spectro 0.9.10; it does not override MLX globally.
Wheel URLs and hashes are fixed in `python-packages.nix`, and other dependencies
follow this flake's nixpkgs pin. Offline checks cover CLI, catalog and cache
handling; model inference runs outside the build sandbox.

Models default to `~/.cache/mlx-audio-separator/models`.
`AUDIO_SEPARATOR_MODEL_DIR` or `--model_file_dir` selects another location.
Converted Demucs models can use `~/.cache/mlx-audio-separator/demucs` or
`MLX_AUDIO_SEPARATOR_DEMUCS_CACHE_DIR`. Models and generated audio are not bundled.
