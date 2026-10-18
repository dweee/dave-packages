{
  lib,
  runCommand,
  makeWrapper,
  ghidra,
  kuna,
  jdk21,
  stdenv,
}:
let
  platform =
    {
      x86_64-linux = "linux_x86_64";
      aarch64-linux = "linux_arm_64";
      aarch64-darwin = "mac_arm_64";
    }
    .${stdenv.hostPlatform.system};
in
runCommand "ghidra-kuna-${ghidra.version}"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = ghidra.meta // {
      description = "Ghidra with the source-built Kuna headless decompiler";
    };
    passthru = { inherit ghidra kuna; };
  }
  ''
    # Ghidra discovers its installation from its JAR and launcher paths.
    # Give headless consumers a separate installation with the Kuna core.
    cp -a --reflink=auto ${ghidra}/. "$out/"
    chmod -R u+w "$out"
    target="$out/lib/ghidra/Ghidra/Features/Decompiler/os/${platform}/decompile"
    rm -f "$target"
    ln -s ${kuna}/bin/kuna_ghidra "$target"
    rm -f "$out/lib/ghidra/support/launch.sh"
    makeWrapper "$out/lib/ghidra/support/.launch.sh-wrapped" \
      "$out/lib/ghidra/support/launch.sh" \
      --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra" \
      --prefix PATH : ${lib.makeBinPath [ jdk21 ]}
    rm -f "$out/bin/ghidra" "$out/bin/ghidra-analyzeHeadless"
    ln -s "$out/lib/ghidra/ghidraRun" "$out/bin/ghidra"
    ln -s "$out/lib/ghidra/support/analyzeHeadless" "$out/bin/ghidra-analyzeHeadless"
  ''
