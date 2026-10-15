{
  lib,
  writeShellApplication,
  python3,
  stdenv,
  gdb,
  lldb,
  src,
}: let
  pythonEnv = python3.withPackages (ps: [ps.mcp]);
in
  writeShellApplication {
    name = "gdb-mcp";
    runtimeInputs =
      [pythonEnv stdenv.cc]
      ++ lib.optionals stdenv.hostPlatform.isLinux [gdb]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [lldb];
    text = ''
      export PYTHONPATH=${src}/src''${PYTHONPATH:+:$PYTHONPATH}
      exec python -m gdb_mcp "$@"
    '';
    meta = {
      description = "MCP server for agent-driven debugging via GDB or LLDB (DAP)";
      homepage = "https://github.com/birdeclipse/gdb-mcp";
      license = lib.licenses.mit;
      mainProgram = "gdb-mcp";
    };
  }
