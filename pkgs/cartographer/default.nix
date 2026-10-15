{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags ? [],
}:
stdenv.mkDerivation {
  pname = "cartographer";
  version = "0-unstable-2020-08-01";

  src = fetchFromGitHub {
    owner = "LWSS";
    repo = "Cartographer";
    rev = "78a704acb95505a605c0f8e46d41c38e46b56175";
    hash = "sha256-EBf4I77o0iL7EYUP74AXJ/mSKsZyjqKjJI1wcrEzohc=";
  };

  patches = [./kernel-compat.patch];

  postPatch = ''
    cp ${./kallsyms-kprobe.c} kallsyms.c
  '';

  hardeningDisable = [
    "pic"
    "format"
  ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags =
    kernelModuleMakeFlags
    ++ [
      "KERNELRELEASE=${kernel.modDirVersion}"
      "KERNEL_PATH=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];

  installPhase = ''
    runHook preInstall
    install -D cartographer_module.ko \
      $out/lib/modules/${kernel.modDirVersion}/extra/cartographer_module.ko
    runHook postInstall
  '';

  meta = {
    description = "Kernel module that filters /proc/*/maps (kprobe kallsyms, no LIVEPATCH)";
    homepage = "https://github.com/LWSS/Cartographer";
    license = lib.licenses.gpl2Only;
    platforms = ["x86_64-linux"];
  };
}
