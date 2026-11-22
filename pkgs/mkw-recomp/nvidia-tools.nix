# NVIDIA's nvdisasm and ptxas from CUDA 12.8, the packages sm86/spec/spec.py pins (PINS: same URLs and sha256), with
# their ELF interpreter and libraries patched for Nix. Why: the setup builds the SM86 spec by running them, and on NixOS
# the binaries as NVIDIA ships them do not start (no /lib64/ld-linux-x86-64.so.2). The wrapper names this folder in
# MKW_NVIDIA_BIN; spec.py then skips its download.
#
# Unfree and available only through a local opt-in.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  redist = "https://developer.download.nvidia.com/compute/cuda/redist";
  # keep in step with sm86/spec/spec.py PINS
  pins = {
    x86_64-linux = {
      nvdisasm = {
        url = "${redist}/cuda_nvdisasm/linux-x86_64/cuda_nvdisasm-linux-x86_64-12.8.90-archive.tar.xz";
        sha256 = "8ac63f4079c47707ec958af3a97ceeb18194e16827a2766058f5872f6c3412ae";
      };
      ptxas = {
        url = "${redist}/cuda_nvcc/linux-x86_64/cuda_nvcc-linux-x86_64-12.8.93-archive.tar.xz";
        sha256 = "9961b3484b6b71314063709a4f9529654f96782ad39e72bf1e00f070db8210d3";
      };
    };
    aarch64-linux = {
      nvdisasm = {
        url = "${redist}/cuda_nvdisasm/linux-sbsa/cuda_nvdisasm-linux-sbsa-12.8.90-archive.tar.xz";
        sha256 = "250ae30e878b0c4c1553e7c7f28c2c763902c807b5f493ebc16e6e10c71213f2";
      };
      ptxas = {
        url = "${redist}/cuda_nvcc/linux-sbsa/cuda_nvcc-linux-sbsa-12.8.93-archive.tar.xz";
        sha256 = "dc0b713ce69fd921aa53ac68610717d126fc273a3c554b0465cf44d7e379f467";
      };
    };
  };
  pin =
    pins.${stdenv.hostPlatform.system}
      or (throw "mkw-recomp-nvidia-tools: no NVIDIA packages for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "mkw-recomp-nvidia-tools";
  version = "12.8";

  srcs = [
    (fetchurl pin.nvdisasm)
    (fetchurl pin.ptxas)
  ];
  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;
  # The binaries are NVIDIA's; stripping changes nothing the setup needs and risks the text spec.py reads.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 cuda_nvdisasm-*/bin/nvdisasm $out/bin/nvdisasm
    install -Dm755 cuda_nvcc-*/bin/ptxas $out/bin/ptxas
    install -Dm644 cuda_nvdisasm-*/LICENSE $out/share/licenses/mkw-recomp-nvidia-tools/LICENSE
    runHook postInstall
  '';

  meta = {
    description = "NVIDIA nvdisasm and ptxas 12.8, which mkw-recomp's setup runs to build the SM86 spec";
    homepage = "https://developer.nvidia.com/cuda-toolkit";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames pins;
  };
}
