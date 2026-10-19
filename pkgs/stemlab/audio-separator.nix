{
  lib,
  python3,
  fetchPypi,
  ffmpeg,
  makeWrapper,
}: let
  py = python3.pkgs;
  diffq = py.buildPythonPackage {
    pname = "diffq";
    version = "0.2.4";
    pyproject = true;
    src = fetchPypi {
      pname = "diffq";
      version = "0.2.4";
      hash = "sha256-BJBkhh6XTr8A0LrauLMkx3UDc3FBntoxUJhbnUd7W9I=";
    };
    build-system = [py.setuptools py.cython];
    dependencies = [py.cython py.numpy py.torch];
    pythonImportsCheck = ["diffq" "diffq.bitpack"];
    meta.license = lib.licenses.cc-by-nc-40;
  };
  onnx2torch = py.buildPythonPackage {
    pname = "onnx2torch-py313";
    version = "1.6.0";
    pyproject = true;
    src = fetchPypi {
      pname = "onnx2torch_py313";
      version = "1.6.0";
      hash = "sha256-0ntUx+Fw8SrSUv4Ybmyrjzyt6O5OWWaCrMWjr92tt1M=";
    };
    build-system = [py.setuptools];
    # Use nixpkgs' released ONNX in place of the nightly distribution.
    pythonRemoveDeps = ["onnx-weekly"];
    dependencies = [py.numpy py.onnx py.torch py.torchvision];
    pythonImportsCheck = ["onnx2torch"];
    meta.license = lib.licenses.asl20;
  };
in
  py.buildPythonApplication {
    pname = "audio-separator";
    version = "0.47.0";
    pyproject = true;
    src = fetchPypi {
      pname = "audio_separator";
      version = "0.47.0";
      hash = "sha256-COwYLN2Fb+e3Dg7BimJftJzeNb4QIgOm0LEtpqv8vDU=";
    };
    build-system = [py.poetry-core];
    # Reuse the flake's pinned native packages. Recheck inference when the
    # pin changes: upstream requests older beartype/rotary/samplerate.
    pythonRemoveDeps = ["onnx-weekly"];
    pythonRelaxDeps = ["beartype" "rotary-embedding-torch" "samplerate"];
    dependencies = with py; [
      audioop-lts
      audioread
      beartype
      diffq
      einops
      julius
      librosa
      ml-collections
      numpy
      onnx
      onnx2torch
      onnxruntime
      packaging
      pydub
      pyyaml
      requests
      resampy
      rotary-embedding-torch
      samplerate
      scipy
      six
      soundfile
      torch
      tqdm
    ];
    nativeBuildInputs = [makeWrapper];
    makeWrapperArgs = ["--prefix PATH : ${lib.makeBinPath [ffmpeg]}"];
    pythonImportsCheck = ["audio_separator.separator" "audio_separator.separator.architectures.demucs_separator"];
    meta = {
      description = "Local music stem separation backend for StemLab";
      homepage = "https://github.com/nomadkaraoke/python-audio-separator";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-darwin"];
      mainProgram = "audio-separator";
    };
  }
