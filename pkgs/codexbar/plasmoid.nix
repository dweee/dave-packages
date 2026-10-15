# psimaker/codexbar-plasmoid. Needs codexbar-cli on PATH (0.43+).
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codexbar-plasmoid";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/psimaker/codexbar-plasmoid/releases/download/v${finalAttrs.version}/com.github.psimaker.codexbar-${finalAttrs.version}.plasmoid";
    hash = "sha256-riBwGaLMV6X0hTrxH6Bpus9/4zsd7ORhPrjADkdRyH4=";
  };

  nativeBuildInputs = [unzip];

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    dest=$out/share/plasma/plasmoids/com.github.psimaker.codexbar
    mkdir -p $dest
    cp -a metadata.json contents $dest/
    runHook postInstall
  '';

  meta = {
    description = "KDE Plasma 6 panel widget for CodexBar usage limits";
    homepage = "https://github.com/psimaker/codexbar-plasmoid";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
