{
  lib,
  callPackage,
  fetchzip,
  ghidra-bin,
  writeShellApplication,
  rea,
  kuna,
  jdk21,
}:
let
  # REA 6.7 accepts 12.1.x; the catalog's 12.2 requires a different bridge/JDK.
  ghidraForRea = (ghidra-bin.override { openjdk25 = jdk21; }).overrideAttrs {
    version = "12.1.4";
    versiondate = "20260921";
    src = fetchzip {
      url = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip";
      hash = "sha256-ZD4Vs1i7BMvrneAbAiOc7F9iBj64Rbom+PaVO//TzK8=";
    };
  };
  ghidra-kuna = callPackage ../ghidra-kuna {
    ghidra = ghidraForRea;
    openjdk25 = jdk21;
  };
in
(writeShellApplication {
  name = "rea";
  runtimeInputs = [
    kuna
    jdk21
  ];
  text = ''
    export GHIDRA_INSTALL_DIR="''${GHIDRA_INSTALL_DIR:-${ghidra-kuna}/lib/ghidra}"
    export NIX_GHIDRAHOME="$GHIDRA_INSTALL_DIR/Ghidra"
    export JAVA_HOME="''${JAVA_HOME:-${jdk21.home}}"
    export REA_KUNA_COMMAND="''${REA_KUNA_COMMAND:-${kuna}/bin/kuna}"
    export REA_ANALYSIS_PROVIDER="''${REA_ANALYSIS_PROVIDER:-ghidra}"
    exec ${lib.getExe rea} "$@"
  '';
  meta = rea.meta;
}).overrideAttrs
  (_: {
    passthru = { inherit rea kuna ghidra-kuna; };
  })
