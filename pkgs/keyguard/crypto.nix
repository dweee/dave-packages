{
  lib,
  src,
  version,
  cmake,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "keyguard-crypto-jni";
  inherit src version;

  sourceRoot = "${src.name}/util/crypto/rust";

  cargoHash = "sha256-z1nkymE2DsB4dXn8e3n4+JNifIqAc0FgNddL2wSdP0k=";

  cargoBuildFlags = [
    "--package"
    "keyguard-crypto-jni"
  ];

  nativeBuildInputs = [cmake];
  env.AWS_LC_SYS_CMAKE_BUILDER = 1;

  meta = {
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
