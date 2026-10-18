{
  lib,
  writeShellApplication,
  rea,
  kuna,
  ghidra-kuna,
  jdk21,
}:
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
