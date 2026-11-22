# Linux-hosted UCRT toolchain used by the upstream Windows release builders.
{
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
  libxml2_13,
  ncurses,
  xz,
  zlib,
  zstd,
  version,
  hash,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "llvm-mingw-ucrt";
  inherit version;
  src = fetchurl {
    url = "https://github.com/mstorsjo/llvm-mingw/releases/download/${version}/llvm-mingw-${version}-ucrt-ubuntu-22.04-x86_64.tar.xz";
    sha256 = hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    libxml2_13
    ncurses
    xz
    zlib
    zstd
  ];
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"
    printf '%s' '${version}' > "$out/.version"
    runHook postInstall
  '';
  passthru.archive = finalAttrs.src;
  meta.platforms = [ "x86_64-linux" ];
})
