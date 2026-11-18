{
  runCommand,
  python3,
  ghidra,
  jdk25,
  extension,
}:
let
  withMcp = ghidra.withExtensions (_: [ extension ]);
in
runCommand "ghidra-mcp-real-api-compatibility"
  {
    nativeBuildInputs = [
      python3
      withMcp
      jdk25
    ];
  }
  ''
    # The smoke deliberately tests x86 decoder identity, including on ARM hosts.
    # This inert ELF is parsed by Ghidra; it is never executed.
    python ${./compatibility-fixture.py} fixture
    mkdir -p "$TMPDIR/project" "$TMPDIR/home"
    export JAVA_HOME=${jdk25.home}
    export JAVA_TOOL_OPTIONS="-Duser.home=$TMPDIR/home -Djava.io.tmpdir=$TMPDIR"
    export GHIDRA_JAVA_OPTIONS="$JAVA_TOOL_OPTIONS"
    if ! ghidra-analyzeHeadless "$TMPDIR/project" compatibility \
      -import "$PWD/fixture" -scriptPath ${extension.src}/ghidra_scripts \
      -postScript FlakeyCompatibilitySmoke.java "$TMPDIR/passed" \
      -analysisTimeoutPerFile 90 -max-cpu 2 -deleteProject \
      > "$TMPDIR/headless.log" 2>&1; then
      cat "$TMPDIR/headless.log"
      exit 1
    fi
    if ! grep -Fx GHIDRA_MCP_COMPATIBILITY_PASSED "$TMPDIR/passed"; then
      cat "$TMPDIR/headless.log"
      exit 1
    fi
    mkdir -p "$out"
    cp "$TMPDIR/passed" "$TMPDIR/headless.log" "$out/"
  ''
