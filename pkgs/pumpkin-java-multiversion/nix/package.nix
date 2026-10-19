{
  lib,
  runCommand,
  fetchFromGitHub,
  makeRustPlatform,
  rust-bin,
  pumpkin,
}: let
  toolchain = rust-bin.stable.latest.minimal.override {targets = ["wasm32-wasip2"];};
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
  upstream = fetchFromGitHub {
    owner = "Pumpkin-MC";
    repo = "pumpkin-java-multiversion";
    rev = "74cccd2a98819038bc7b91253f05f4c882ce7dba";
    hash = "sha256-0gRE9Oye8hHLg5+EbXyMNhacDUmxElgt1H/PWOz5GZI=";
  };
  source = runCommand "pumpkin-java-multiversion-pinned-api-source" {} ''
    cp -r ${upstream} $out
    chmod -R u+w $out
    substituteInPlace $out/Cargo.toml \
      --replace-fail '../Pumpkin/crates/' '${pumpkin.src}/crates/'
    cp ${../Cargo.lock} $out/Cargo.lock
  '';
in
  rustPlatform.buildRustPackage {
    pname = "pumpkin-java-multiversion";
    version = "0.1.0-pumpkin-0.2";
    src = source;
    cargoHash = "sha256-2MMFMa1qsp96YFi1BR9DqYAueHJQDnAnKBDmPpTMVE0=";
    env = {
      RUST_MIN_STACK = "33554432";
      # Avoid expensive O3 optimization of the generated Minecraft data tables.
      CARGO_PROFILE_RELEASE_OPT_LEVEL = "1";
    };
    buildPhase = ''
      runHook preBuild
      cargo build --frozen --release --target wasm32-wasip2
      runHook postBuild
    '';
    doCheck = false; # Needs the Pumpkin WASM host; validated in an isolated server.
    installPhase = ''
      runHook preInstall
      install -Dm444 target/wasm32-wasip2/release/pumpkin_java_multiversion.wasm $out/pumpkin_java_multiversion.wasm
      runHook postInstall
    '';
    meta = {
      description = "Official Java protocol compatibility plugin for Pumpkin";
      homepage = "https://github.com/Pumpkin-MC/pumpkin-java-multiversion";
      license = with lib.licenses; [mit asl20];
      platforms = lib.platforms.linux;
    };
  }
