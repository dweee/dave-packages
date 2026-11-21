# dweee/codexbar-plasmoid: fork of psimaker/codexbar-plasmoid with the macOS
# CodexBar parity work (structured pace, session-quota forecasts, reset
# confetti, the macOS notification set). Needs codexbar-cli on PATH or the
# widget's cliPath setting.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codexbar-plasmoid";
  version = "0.7.0-dave.2";

  src = fetchFromGitHub {
    owner = "dweee";
    repo = "codexbar-plasmoid";
    # feat/google-developer-program (PR #2)
    rev = "2919e4cac1172cf734316c5d95b46d9cf91de0d6";
    hash = "sha256-ip0POFwLl787G+7UWcxmfQL2PFf1BftjZ+GgHd3Fn+w=";
  };

  dontBuild = true;

  # The pure reducers (pace, forecasts, reset detection, notifications) carry
  # node tests ported from upstream CodexBar's Swift suite. The python tests
  # need git and packaging tools, so only the JS suites run here.
  doCheck = true;
  nativeCheckInputs = [ nodejs ];
  checkPhase = ''
    runHook preCheck
    for t in tests/test-*.js; do
      node "$t"
    done
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    dest=$out/share/plasma/plasmoids/com.github.psimaker.codexbar
    mkdir -p $dest
    cp -a metadata.json contents $dest/
    runHook postInstall
  '';

  meta = {
    description = "KDE Plasma 6 panel widget for CodexBar usage limits, with macOS CodexBar parity";
    homepage = "https://github.com/dweee/codexbar-plasmoid";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
