{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
}:
assert stdenvNoCC.hostPlatform.isDarwin;
let
  pname = "sable-desktop-legacy";
  version = "1.22.11";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  # Upstream's flake builds the web UI, not the desktop application.
  # The universal release bundle contains both arm64 and x86_64 slices.
  src = fetchurl {
    url = "https://github.com/SableClient/Sable-Legacy/releases/download/v${version}/Sable-${version}-macos-universal.app.tar.gz";
    hash = "sha256-eZxlZM6Q2PvMIfes4g2p6qK8FohA2884PZDUIvpa0sY=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  # Preserve the upstream bundle and its Mach-O load commands.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications $out/bin
    cp -R Sable.app $out/Applications/
    # NSBundle uses argv[0] to locate the bundle. A symlink in bin/ makes
    # Tauri's notifications plugin reject the launch as a non-app process.
    makeWrapper $out/Applications/Sable.app/Contents/MacOS/sable $out/bin/sable-legacy \
      --argv0 $out/Applications/Sable.app/Contents/MacOS/sable

    runHook postInstall
  '';

  meta = {
    description = "Legacy Matrix client forked from Cinny (Tauri desktop build)";
    homepage = "https://sable.moe";
    changelog = "https://github.com/SableClient/Sable-Legacy/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
    mainProgram = "sable-legacy";
  };
}
