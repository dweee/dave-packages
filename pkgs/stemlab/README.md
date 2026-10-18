# StemLab on Rotna and Lapwolf

The public StemLab source at `a30f6f8ff85e5142c6374496efd0624443976ada`
provides the Qt producer GUI and `stem-separate` CLI. This packages that source
with audio-separator 0.47.0, PySide6 and FFmpeg. It does not run the upstream
installer or create a pip environment. Supported targets are `aarch64-darwin`
and `x86_64-linux`.

Build and launch from the Flakey checkout on either machine:

```sh
nix build .#stemlab
nix run .#stemlab
./result/bin/stem-separate balanced /path/to/input.wav /path/to/new-output
```

The verified builds are retained on both machines and can be launched before
a system switch:

```sh
~/.local/state/flakey-builds/stemlab/bin/stemlab
~/.local/state/flakey-builds/stemlab/bin/stem-separate balanced /path/to/input.wav /path/to/new-output
```

Both host configurations import `users/d/stemlab.nix`, which enables the Home
Manager module exported as `homeModules.stemlab`. After a separately authorized
normal system switch, `stemlab` and `stem-separate` are on PATH. Rotna also gets
`StemLab.app`; Lapwolf gets a desktop application entry. An external Home Manager
configuration can import `pkgs/stemlab/module.nix`, set
`programs.stemlab.enable = true`, and provide `programs.stemlab.package`.

The package follows this flake's Python and native dependency versions. In
particular, released ONNX replaces `onnx-weekly`; beartype, rotary-embedding-torch
and samplerate use Nixpkgs versions instead of upstream's narrower bounds.
On Linux the Python closure explicitly disables CUDA and ROCm, even though
Lapwolf enables ROCm globally; this preserves the cached CPU packages. macOS
keeps upstream's automatic Apple MPS selection when available.
The build checks imports of the real backend, including Demucs, and runs the
upstream offline wrapper and Qt queue tests. The queue tests use real Qt with
mocked separation; they do not prove model inference, audible preview or DAW
drag-and-drop. Upstream's desktop acceptance evidence covers Linux, so macOS
desktop behavior needs separate validation.
One upstream fixture creates six names differing only by case. It is skipped
on case-insensitive filesystems, where those six distinct files cannot exist.
Generated test scripts use explicit Nix interpreters, since `/usr/bin/env`
is unavailable inside a Linux Nix sandbox.

Models are downloaded on first use into
`${XDG_CACHE_HOME:-$HOME/.cache}/808sgn-stem-lab/models`. Set `STEM_LAB_MODELS`
to use another cache. Weights and generated audio stay outside the Nix store.
The Nix package owns the backend; `STEM_LAB_VENV` is not used to select it.
Use a new output directory for CLI jobs: the GUI checks occupied destinations,
but the CLI retains upstream's output behavior.

Balanced and Fast are the upstream producer alpha's supported four-stem
presets. Other presets remain experimental. Code is MIT; the `diffq`
dependency is CC-BY-NC-4.0, and model weights retain their own terms.

Full host activation is independent of package builds and tests. This change
does not itself switch either system generation.

Validated on 2026-10-15: native builds on Rotna and Lapwolf; 55 passing tests
plus one filesystem-dependent skip on Rotna, and all 56 tests passing on
Lapwolf. Real Balanced/HTDemucs separation of synthetic one-second stereo
audio produced four 44.1 kHz stereo WAVs on each host. Rotna selected Apple
MPS; Lapwolf used the CPU. These checks do not assess separation quality on
music or replace manual playback and DAW drag-and-drop checks.
