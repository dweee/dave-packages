{
  lib,
  runCommand,
  fetchFromGitHub,
  applyPatches,
  makeRustPlatform,
  rust-bin,
  pumpkin,
}: let
  toolchain = rust-bin.stable.latest.minimal.override {
    targets = ["wasm32-wasip2"];
  };
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
  upstream = fetchFromGitHub {
    owner = "PingGai";
    repo = "Pumpkin-TPSBar";
    rev = "ae4271716bce76519944681c4b105c16f34f8643";
    hash = "sha256-joxLEujrikoEI5CrIM70XDBodALh5oho2GC4gG8fQkU=";
  };
  # Upstream pins a different API revision. Compile against precisely the
  # server's API and WIT files; the 0.1 version alone does not ensure compatibility.
  source = runCommand "pumpkin-tpsbar-pinned-api-source" {} ''
    cp -r ${upstream} $out
    chmod -R u+w $out
    substituteInPlace $out/Cargo.toml \
      --replace-fail 'version = "0.1.0", git = "https://github.com/Pumpkin-MC/Pumpkin.git", rev = "0844e929112d5cda772bc8b0de51e38930142704", package = "pumpkin-plugin-api"' \
      'path = "${pumpkin.src}/crates/pumpkin-plugin-api"'
    cp ${../Cargo.lock} $out/Cargo.lock
  '';
in
  rustPlatform.buildRustPackage {
    pname = "pumpkin-tpsbar";
    version = "0.1.0-pumpkin-0.2";
    src = applyPatches {
      src = source;
      patches = [../pumpkin-0.2.patch];
    };
    cargoHash = "sha256-2If2ywOfUexZqOUUDGFSe4IgfAtMa3SJJ8qXnGk0sL0=";
    buildPhase = ''
      runHook preBuild
      cargo build --frozen --release --target wasm32-wasip2
      runHook postBuild
    '';
    doCheck = false; # Component needs Pumpkin's host imports; integration-tested there.
    installPhase = ''
      runHook preInstall
      install -Dm444 target/wasm32-wasip2/release/tpsbar.wasm $out/tpsbar.wasm
      runHook postInstall
    '';
    meta = {
      description = "TPS/MSPT/ping BossBar rebuilt for the pinned Pumpkin API";
      homepage = "https://github.com/PingGai/Pumpkin-TPSBar";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
    };
  }
