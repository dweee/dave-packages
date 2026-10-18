# nixpkgs' Tauon currently includes Linux-only PipeWire unconditionally.
{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation {
  pname = "tauon";
  version = "13.0.0";
  src = fetchurl {
    url = "https://github.com/Taiko2k/Tauon/releases/download/v13.0.0/Tauon-signed.dmg";
    hash = "sha256-eornjwMWK1gkIfVs8r6CSKBHtp73+3pghjeSDqjuJJA=";
  };
  nativeBuildInputs = [undmg];
  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    app=$(find . -maxdepth 2 -type d -name '*.app' -print -quit)
    test -n "$app"
    cp -R "$app" $out/Applications/
    runHook postInstall
  '';
  meta = {
    description = "Music player with local libraries and synchronized lyrics";
    homepage = "https://tauonmusicbox.rocks/";
    license = lib.licenses.gpl3Only;
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
