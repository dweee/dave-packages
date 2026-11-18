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
  version = "0.7.0-dave.1";

  src = fetchFromGitHub {
    owner = "dweee";
    repo = "codexbar-plasmoid";
    # feat/macos-parity
    rev = "44800ed5bc26a6f9914fe42b4d58d98aabf98bd2";
    hash = "sha256-k2rhaV9qAnZmLqf63MKcsRbWX6zddoXbIe/P3x/TjeI=";
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
