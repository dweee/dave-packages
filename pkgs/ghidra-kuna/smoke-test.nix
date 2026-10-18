{
  runCommand,
  stdenv,
  ghidra-kuna,
  jdk21,
}:
runCommand "ghidra-kuna-headless-smoke"
  {
    nativeBuildInputs = [
      stdenv.cc
      ghidra-kuna
      jdk21
    ];
  }
  ''
    # The return-value check also makes the fixture executable independently of
    # the decompiler, so bad compiler flags cannot silently weaken the test.
    cc -O1 -g -fno-inline ${./fixture.c} -o "$TMPDIR/fixture"
    "$TMPDIR/fixture"
    mkdir -p "$TMPDIR/project" "$TMPDIR/ghidra-home"
    export JAVA_HOME=${jdk21.home}
    # LaunchSupport is a separate JVM and must also have a writable sandbox home,
    # notably on Darwin where it saves the selected JDK under ~/Library/ghidra.
    export JAVA_TOOL_OPTIONS="-Duser.home=$TMPDIR/ghidra-home -Djava.io.tmpdir=$TMPDIR"
    export GHIDRA_JAVA_OPTIONS="-Duser.home=$TMPDIR/ghidra-home -Djava.io.tmpdir=$TMPDIR"
    if ! ghidra-analyzeHeadless "$TMPDIR/project" kuna-smoke \
      -import "$TMPDIR/fixture" -scriptPath ${./.} \
      -postScript KunaSmoke.java "$TMPDIR/decompiled.c" \
      -analysisTimeoutPerFile 90 -max-cpu 2 -deleteProject \
      > "$TMPDIR/headless.log" 2>&1; then
      cat "$TMPDIR/headless.log"
      exit 1
    fi
    # Ghidra can log a script error without returning a failing exit status.
    # The script only writes this file after its backend and body assertions.
    if ! test -s "$TMPDIR/decompiled.c"; then
      cat "$TMPDIR/headless.log"
      exit 1
    fi
    # Check the recovered body by compiling and executing the emitted C, not
    # merely checking for a version comment or a successful process launch.
    cp "$TMPDIR/decompiled.c" "$TMPDIR/recovered.c"
    cat >> "$TMPDIR/recovered.c" <<'C'
    int main(void) {
        return kuna_probe(5U) == 38U && kuna_probe(0U) == 3U
            && kuna_constant() == 0x4b554e41U ? 0 : 1;
    }
    C
    cc -O1 "$TMPDIR/recovered.c" -o "$TMPDIR/recovered"
    "$TMPDIR/recovered"
    mkdir -p "$out"
    cp "$TMPDIR/fixture" "$TMPDIR/headless.log" "$TMPDIR/decompiled.c" "$out/"
  ''
