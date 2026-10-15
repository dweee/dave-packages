{
  lib,
  writeShellApplication,
  python3,
  src,
}: let
  pythonEnv = python3.withPackages (ps: [
    ps.fastmcp
    ps.httpx
  ]);
in
  writeShellApplication {
    name = "slskd-mcp";
    runtimeInputs = [pythonEnv];
    text = ''
      exec fastmcp run ${src}/generated/server.py "$@"
    '';
    meta = {
      description = "MCP server for the slskd Soulseek API";
      homepage = "https://github.com/abl030/slskd-mcp";
      license = lib.licenses.mit;
      mainProgram = "slskd-mcp";
    };
  }
