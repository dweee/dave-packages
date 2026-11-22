# Strata's prebuilt Apple Silicon server (with its bundled relocatable CPython)
# and the Metal engine for Inkling-2-Mini, from the v0.2.19 GitHub release.
# Only the server is exposed: `strata launch`/`strata update` download engines
# and models into the home folder at run time, which a store package must not do.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
}:
let
  release = "0.2.19";
  engineVersion = "0.1.65";
  asset =
    name: hash:
    fetchurl {
      url = "https://github.com/Niko1221/Strata/releases/download/v${release}/${name}";
      inherit hash;
    };
  # Hashes are the release's SHA256SUMS.txt entries.
  control = asset "strata-control-${engineVersion}-macos-arm64.tar.gz" "sha256-xa1+gVkp6iB2z8ZlEKwUJyfRXeOxf1JWvBWv8adO3bw=";
  inkling = asset "strata-inkling-${engineVersion}-macos-arm64-metal.tar.gz" "sha256-+inPXaenqhzriNH7ZBwpEgFRaCMY2PBVa7nUDvvRjz8=";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "strata-bin";
  version = engineVersion;

  srcs = [
    control
    inkling
  ];
  unpackPhase = ''
    runHook preUnpack
    mkdir control inkling
    tar -xzf ${control} -C control
    tar -xzf ${inkling} -C inkling
    runHook postUnpack
  '';

  nativeBuildInputs = [ makeWrapper ];

  # The engine and CPython are signed upstream Mach-O files; stripping or
  # rewriting them (or the Python shebangs) would only break them.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/strata $out/libexec/strata/inkling $out/bin
    cp -a control/. $out/share/strata/
    cp -a inkling/. $out/libexec/strata/inkling/
    ln -s $out/libexec/strata/inkling/strata-inkling $out/bin/strata-inkling
    # The server resolves its web UI, tokenizer tools and dialects from its own
    # tree; state goes to $XDG_STATE_HOME and the run config's log path.
    makeWrapper $out/share/strata/python/bin/python3 $out/bin/strata-serve \
      --chdir $out/share/strata \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --set PYTHONNOUSERSITE 1 \
      --add-flags "-m serve.server --engine strata"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/strata-serve --help > /dev/null
    grep -q '"version": "${engineVersion}"' $out/libexec/strata/inkling/BUILD.json
    runHook postInstallCheck
  '';

  passthru.inklingEngine = "${finalAttrs.finalPackage}/libexec/strata/inkling/strata-inkling";

  meta = {
    description = "Strata inference server and Metal Inkling-2-Mini engine (prebuilt)";
    homepage = "https://github.com/Niko1221/Strata";
    changelog = "https://github.com/Niko1221/Strata/releases/tag/v${release}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "strata-serve";
  };
})
