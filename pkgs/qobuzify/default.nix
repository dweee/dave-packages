{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  appimageTools,
  makeWrapper,
  mpv,
  unzip,
}:
let
  pname = "qobuzify";
  version = "0.3.9";
  meta = {
    description = "Qobuz desktop client with synchronized word-by-word lyrics";
    homepage = "https://github.com/matthewprince/qobuzify";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
  linuxSrc = fetchurl {
    url = "https://github.com/matthewprince/qobuzify/releases/download/v${version}/Qobuzify-${version}-linux-x86_64.AppImage";
    hash = "sha256-oZs++YnrrW2VUtWmgoolAG8niCYM0q69vixDEUDqo+o=";
  };
  contents = appimageTools.extract {
    inherit pname version;
    src = linuxSrc;
    # The upstream Linux AppImage embeds another full portable mpv runtime.
    # QZ_MPV is an upstream-supported override; reuse Nix's shared player.
    postExtract = ''
      rm -rf $out/resources/mpv
    '';
  };
in
if stdenv.hostPlatform.isLinux then
  appimageTools.wrapAppImage {
    inherit pname version meta;
    src = contents;
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      desktop=$(find ${contents} -maxdepth 1 -name '*.desktop' -print -quit)
      test -n "$desktop"
      cp "$desktop" $out/share/applications/qobuzify.desktop
      substituteInPlace $out/share/applications/qobuzify.desktop --replace-fail "Exec=AppRun --no-sandbox" "Exec=qobuzify"
      if [ -d ${contents}/usr/share/icons ]; then
        cp -r ${contents}/usr/share/icons $out/share/
      fi
      . ${makeWrapper}/nix-support/setup-hook
      wrapProgram $out/bin/qobuzify --add-flags "--no-sandbox" --set QZ_MPV ${lib.getExe mpv}
    '';
  }
else
  stdenvNoCC.mkDerivation {
    inherit pname version meta;
    src = fetchurl {
      url = "https://github.com/matthewprince/qobuzify/releases/download/v${version}/Qobuzify-${version}-mac-universal.zip";
      hash = "sha256-nkbnE+U/IUlFCkZfMwcBH3xZ+j40Luv51EXNk7My+kU=";
    };
    nativeBuildInputs = [ unzip ];
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications
      cp -R Qobuzify.app $out/Applications/
      runHook postInstall
    '';
  }
