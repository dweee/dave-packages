{
  lib,
  src,
  version,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "keyguard-zxcvbn-jni";
  inherit src version;

  sourceRoot = "${src.name}/util/zxcvbn/rust";

  cargoHash = "sha256-KVeQu8Jg0NfN334niHZgZgIaEFkWN73UoYUb0sNfprM=";

  cargoBuildFlags = [
    "--package"
    "keyguard-zxcvbn-jni"
  ];

  meta = {
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
