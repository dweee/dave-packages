{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}: let
  version = "2.0.0-alpha.10";
  sources = {
    x86_64-linux = {
      url = "https://github.com/encounter/nod/releases/download/v${version}/nodtool-linux-x86_64";
      hash = "sha256-+FO4Mmi5VC+vDSiBW8OiPAkK4o6/OX5G+Zy7CBIsgwc=";
    };
    aarch64-linux = {
      url = "https://github.com/encounter/nod/releases/download/v${version}/nodtool-linux-aarch64";
      hash = "sha256-sNlGF+0jkzNIRWacwfdPHk/ODWrLJOi+KMR5aJobkHs=";
    };
    aarch64-darwin = {
      url = "https://github.com/encounter/nod/releases/download/v${version}/nodtool-macos-arm64";
      hash = "sha256-4jykZpmbcgxV5tKcloP86Mx0RRumTq0uVD1QEp8kUoo=";
    };
    x86_64-darwin = {
      url = "https://github.com/encounter/nod/releases/download/v${version}/nodtool-macos-x86_64";
      hash = "sha256-9o9QTcK3JpS0aMp4tqJBQseqXIgA93VkKX9BQ2guZXU=";
    };
  };
  src =
    sources.${stdenv.hostPlatform.system}
    or (throw "nodtool: no prebuilt binary for ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    pname = "nodtool";
    inherit version;

    src = fetchurl {
      inherit (src) url hash;
    };

    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/nodtool
      runHook postInstall
    '';

    meta = {
      description = "Wii/GameCube disc tool used by WiiCompiled to validate and extract dumps";
      homepage = "https://github.com/encounter/nod";
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = lib.attrNames sources;
      mainProgram = "nodtool";
    };
  }
