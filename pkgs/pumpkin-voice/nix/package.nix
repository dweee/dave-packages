{
  lib,
  runCommand,
  fetchFromGitHub,
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
    owner = "hmdnnrmn";
    repo = "PumpkinVoice";
    rev = "b9c7d321e07771ab66115894133f34954d508101";
    hash = "sha256-HhD26JqGfxSpxUAkjUgGUEv5yDD3u7gz7xqGcwkeXqg=";
  };
  # Release WASM imports an incompatible WIT interface despite the same 0.1
  # version number. Recompile against precisely the server's API and WIT files.
  source = runCommand "pumpkin-voice-pinned-api-source" {} ''
    cp -r ${upstream} $out
    chmod -R u+w $out
    substituteInPlace $out/Cargo.toml \
      --replace-fail 'git = "https://github.com/Pumpkin-MC/Pumpkin.git", branch = "master", package = "pumpkin-plugin-api"' \
      'path = "${pumpkin.src}/crates/pumpkin-plugin-api"'
    cp ${../Cargo.lock} $out/Cargo.lock
  '';
in
  rustPlatform.buildRustPackage {
    pname = "pumpkin-voice";
    version = "1.2.0-pumpkin-0.2";
    src = source;
    cargoHash = "sha256-xWMkHXUkWY96rWVU1OTbHITeTk6vGqlHdydRGtihTYk=";
    buildPhase = ''
      runHook preBuild
      cargo build --frozen --release --target wasm32-wasip2
      runHook postBuild
    '';
    doCheck = false; # Component needs Pumpkin's host imports; integration-tested there.
    installPhase = ''
      runHook preInstall
      install -Dm444 target/wasm32-wasip2/release/pumpkin_voice.wasm $out/pumpkin_voice.wasm
      runHook postInstall
    '';
    meta = {
      description = "Simple Voice Chat backend rebuilt for the pinned Pumpkin API";
      homepage = "https://github.com/hmdnnrmn/PumpkinVoice";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  }
