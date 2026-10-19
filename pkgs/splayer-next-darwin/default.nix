{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation {
  pname = "splayer-next";
  version = "1.1.0";
  src = fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer-Next/releases/download/v1.1.0/SPlayer-Next-1.1.0-arm64.zip";
    hash = "sha256-eGY4JDiHrYThtaTDt7U1ctj2g1MTT/GJzD8wERLj9SI=";
  };
  nativeBuildInputs = [unzip];
  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -R SPlayer-Next.app $out/Applications/
    runHook postInstall
  '';
  meta = {
    description = "Music player with Apple Music-style word-by-word lyrics";
    homepage = "https://github.com/SPlayer-Dev/SPlayer-Next";
    license = lib.licenses.agpl3Only;
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
