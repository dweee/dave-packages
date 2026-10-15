{
  lib,
  stdenv,
  fetchurl,
  jre,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:
stdenv.mkDerivation rec {
  pname = "bitwig-theme-editor";
  version = "2.3.2";

  src = fetchurl {
    url = "https://github.com/Berikai/bitwig-theme-editor/releases/download/${version}/bitwig-theme-editor-${version}.jar";
    hash = "sha256-FNG+io1yEK6A7Bv1TCsE2e0JGVLFaErd2k6qxVaE4co=";
  };

  dontUnpack = true;

  nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenv.hostPlatform.isLinux [copyDesktopItems];

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "bitwig-theme-editor";
      desktopName = "Bitwig Theme Editor";
      comment = "Unofficial theme editor for Bitwig Studio";
      exec = "bitwig-theme-editor";
      categories = ["AudioVideo" "Audio"];
    })
  ];

  installPhase = ''
    runHook preInstall
    install -Dm644 $src "$out/share/bitwig-theme-editor/bitwig-theme-editor-${version}.jar"
    makeWrapper ${lib.getExe jre} $out/bin/bitwig-theme-editor \
      --add-flags "-jar $out/share/bitwig-theme-editor/bitwig-theme-editor-${version}.jar"
    runHook postInstall
  '';

  meta = {
    description = "Unofficial cross-platform theme editor for Bitwig Studio";
    homepage = "https://github.com/Berikai/bitwig-theme-editor";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [binaryBytecode];
    platforms = lib.platforms.unix;
    mainProgram = "bitwig-theme-editor";
  };
}
