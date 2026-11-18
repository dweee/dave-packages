{
  lib,
  writeShellApplication,
  python3,
  stdenv,
  gdb,
  lldb,
  applyPatches,
  src,
}: let
  pythonEnv = python3.withPackages (ps: [ps.mcp]);
  # mcp 2.x renamed FastMCP to MCPServer and removed mcp.server.fastmcp; see
  # https://py.sdk.modelcontextprotocol.io/v2/migration/#fastmcp-renamed-to-mcpserver
  # --replace-fail stops the build once the tracked upstream changes these lines.
  patchedSrc = applyPatches {
    name = "gdb-mcp-source";
    inherit src;
    postPatch = ''
      substituteInPlace src/gdb_mcp/server.py \
        --replace-fail 'from mcp.server.fastmcp import FastMCP' 'from mcp.server.mcpserver import MCPServer' \
        --replace-fail 'mcp = FastMCP("gdb-mcp")' 'mcp = MCPServer("gdb-mcp")'
    '';
  };
in
  writeShellApplication {
    name = "gdb-mcp";
    runtimeInputs =
      [pythonEnv stdenv.cc]
      ++ lib.optionals stdenv.hostPlatform.isLinux [gdb]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [lldb];
    text = ''
      export PYTHONPATH=${patchedSrc}/src''${PYTHONPATH:+:$PYTHONPATH}
      exec python -m gdb_mcp "$@"
    '';
    meta = {
      description = "MCP server for agent-driven debugging via GDB or LLDB (DAP)";
      homepage = "https://github.com/birdeclipse/gdb-mcp";
      license = lib.licenses.mit;
      mainProgram = "gdb-mcp";
    };
  }
