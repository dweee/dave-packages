{
  lib,
  stdenv,
  upstreamMesa,
  meson,
  ninja,
  pkg-config,
  bison,
  flex,
  python3Packages,
  wayland-scanner,
  expat,
  libdrm,
  libgbm,
  libglvnd,
  libx11,
  libxcb,
  libxext,
  libxfixes,
  libxrandr,
  libxshmfence,
  libxxf86vm,
  xorgproto,
  wayland,
  wayland-protocols,
  zstd,
  zlib,
}:
assert stdenv.hostPlatform.isFreeBSD;
stdenv.mkDerivation (finalAttrs: {
  pname = "mesa-freebsd-softpipe";
  inherit (upstreamMesa) version src;
  strictDeps = true;
  # FreeBSD's fortified memcpy is a function-like macro: commas in a C
  # compound literal must be enclosed in parentheses to remain one argument.
  postPatch = ''
    substituteInPlace src/gallium/auxiliary/vl/vl_csc.c \
      --replace-fail 'memcpy(matrix, &(vl_csc_matrix){' 'memcpy(matrix, (&(vl_csc_matrix){' \
      --replace-fail '}, sizeof(vl_csc_matrix));' '}), sizeof(vl_csc_matrix));'
  '';
  mesonAutoFeatures = "disabled";
  depsBuildBuild = [ pkg-config ];
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    bison
    flex
    wayland-scanner
    python3Packages.python
    python3Packages.mako
    python3Packages.pyyaml
    python3Packages.packaging
  ];
  buildInputs = [
    expat
    libdrm
    libgbm
    libglvnd
    libx11
    libxcb
    libxext
    libxfixes
    libxrandr
    libxshmfence
    libxxf86vm
    xorgproto
    wayland
    wayland-protocols
    zstd
    zlib
  ];
  mesonFlags = [
    "-Dplatforms=x11,wayland"
    "-Dgallium-drivers=softpipe"
    "-Dzstd=enabled"
    "-Dvulkan-drivers="
    "-Dvulkan-layers="
    "-Dllvm=disabled"
    "-Dgallium-rusticl=false"
    "-Dteflon=false"
    "-Dglvnd=enabled"
    "-Dgbm=enabled"
    "-Dlibgbm-external=true"
    "-Degl=enabled"
    "-Dglx=dri"
    "-Dgles1=enabled"
    "-Dgles2=enabled"
    "-Dopengl=true"
    "-Dshared-glapi=enabled"
    "-Dglx-direct=true"
    "-Dvalgrind=disabled"
    "-Dlmsensors=disabled"
    "-Dintel-rt=disabled"
    "-Dmicrosoft-clc=disabled"
  ];
  postFixup = ''
    for manifest in "$out"/share/glvnd/egl_vendor.d/*.json; do
      substituteInPlace "$manifest" \
        --replace-fail '"libEGL_' '"'"$out/lib/libEGL_"
    done
  '';
  passthru.drivers = finalAttrs.finalPackage;
  passthru.driverLink = libglvnd.driverLink;
  meta = upstreamMesa.meta // {
    description = "Mesa softpipe EGL/GLES for FreeBSD (software rendering only)";
    platforms = lib.platforms.freebsd;
  };
})
