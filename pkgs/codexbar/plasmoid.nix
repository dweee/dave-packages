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
  version = "0.7.1-dave.2";

  src = fetchFromGitHub {
    owner = "dweee";
    repo = "codexbar-plasmoid";
    # main (0.7.1 + PR #2 googledeveloper provider)
    rev = "44bc2609f3488a8ef21c2b8eaad1ded3759e68bc";
    hash = "sha256-rUfQBM6VLkV1wDNNjDMVSBrCRUvzsMMhrbgvjjXfPMQ=";
  };

  patches = [
    ./patches/summary-pace-markers.patch
    ./patches/quota-presentation.patch
  ];

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
