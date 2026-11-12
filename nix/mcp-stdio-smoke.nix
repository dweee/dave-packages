# Runtime smoke test for MCP stdio wrapper packages: start the server, complete
# the MCP handshake with the SDK client and require the named tools.
{
  lib,
  runCommand,
  python3,
}:
{
  package,
  tools,
  args ? [ ],
}:
runCommand "${package.name}-mcp-stdio-smoke"
  {
    nativeBuildInputs = [ (python3.withPackages (ps: [ ps.mcp ])) ];
  }
  ''
    export HOME="$TMPDIR"
    python3 -I ${./mcp-stdio-smoke.py} \
      ${lib.concatMapStringsSep " " (tool: "--tool ${lib.escapeShellArg tool}") tools} \
      -- ${lib.escapeShellArgs ([ (lib.getExe package) ] ++ args)}
    touch "$out"
  ''
