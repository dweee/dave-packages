{
  lib,
  python314,
  fetchFromGitHub,
  fetchurl,
  fetchPypi,
  ffmpeg,
}: let
  python = python314.override {
    packageOverrides = import ./python-packages.nix {inherit lib fetchurl fetchPypi;};
  };
in
  python.pkgs.buildPythonApplication {
    pname = "mlx-audio-separator";
    version = "0.1.20";
    pyproject = true;
    src = fetchFromGitHub {
      owner = "ssmall256";
      repo = "mlx-audio-separator";
      rev = "2f55dca7441cf8b243f4937d28dfe3dc4d60a8d3";
      hash = "sha256-dfwYwTh3SwtHsMrPC+kMyYSEcHT0Om8ube8Rop8yfTo=";
    };
    build-system = [python.pkgs.setuptools python.pkgs.wheel];
    dependencies = with python.pkgs; [
      mlx
      mlx-audio-io
      mlx-spectro
      numpy
      pyyaml
      requests
      tqdm
      packaging
    ];
    nativeCheckInputs = [python.pkgs.pytestCheckHook];
    # Offline CLI/catalog/cache checks; real Metal inference is checked on
    # Rotna outside the Nix build sandbox with a preconverted MLX model.
    enabledTestPaths = [
      "tests/test_core.py"
      "tests/test_cli_exit_status.py"
      "tests/test_zfturbo_catalog.py"
      "tests/test_model_file_dir.py"
      "tests/test_cache_dir_namespacing.py"
      "tests/test_legacy_model_cache_optout.py"
    ];
    preCheck = ''
      export HOME="$TMPDIR/mlx-separator-test-home"
      mkdir -p "$HOME"
    '';
    pythonImportsCheck = ["mlx_audio_separator" "mlx_audio_io" "mlx_spectro"];
    makeWrapperArgs = ["--prefix PATH : ${lib.makeBinPath [ffmpeg]}"];
    passthru = {inherit python;};
    meta = {
      description = "MLX-native audio stem separation for Apple Silicon";
      homepage = "https://github.com/ssmall256/mlx-audio-separator";
      license = lib.licenses.mit;
      platforms = ["aarch64-darwin"];
      mainProgram = "mlx-audio-separator";
    };
  }
