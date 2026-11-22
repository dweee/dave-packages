{
  lib,
  stdenv,
  rustPlatform,
  python3,
  src,
}:

let
  # Upstream VERSION is the major; release tags determine the minor.
  # Keep the complete upstream version with each reviewed source promotion.
  version = "1.995";
in
rustPlatform.buildRustPackage {
  pname = "kuna";
  inherit version;

  inherit src;
  cargoRoot = "decompiler";
  buildAndTestSubdir = "decompiler";
  cargoLock.lockFile = src + "/decompiler/Cargo.lock";

  nativeBuildInputs = [ python3 ];
  env.KUNA_VERSION = version;

  preBuild = ''
    export CARGO_TARGET_DIR="$PWD/target"
    cargo build --manifest-path decompiler/Cargo.toml --offline --release \
      --target ${stdenv.hostPlatform.rust.rustcTarget} -p kuna-slacomp -j "$NIX_BUILD_CORES"
    target/${stdenv.hostPlatform.rust.rustcTarget}/release/slacomp -a specs
  '';
  cargoBuildFlags = [
    "-p"
    "kuna-cli"
    "-p"
    "kuna-ghidra"
    "-p"
    "kuna-slacomp"
    "-p"
    "kuna-console"
    "-p"
    "kuna-harness"
  ];
  buildFeatures = [ "kuna-cli/embed-specs" ];

  # The complete workspace suite is available through `nix develop -c make specs rust-test`.
  doCheck = false;
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/kuna" --help > /dev/null
    "$out/bin/kuna" catalog --check
    "$out/bin/kuna" install-skill --print | cmp - skills/kuna/SKILL.md
    runHook postInstallCheck
  '';

  postInstall = ''
    mkdir -p "$out/share/kuna/skills/kuna-decompiler" "$out/share/licenses/kuna"
    cp -r specs "$out/share/kuna/specs"
    cp skills/kuna/SKILL.md "$out/share/kuna/skills/kuna-decompiler/SKILL.md"
    cp LICENSE NOTICE "$out/share/licenses/kuna/"
  '';

  meta = {
    description = "Agent-first decompiler with compiled SLEIGH specs and Ghidra backend";
    homepage = "https://github.com/Noelo-Lab/kuna";
    license = lib.licenses.asl20;
    mainProgram = "kuna";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
