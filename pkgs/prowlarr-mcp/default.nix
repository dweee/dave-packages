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
    name = "prowlarr-mcp";
    runtimeInputs = [pythonEnv];
    text = ''
      exec python3 ${src}/prowlarr_mcp.py "$@"
    '';
    meta = {
      description = "MCP server for the Prowlarr API";
      homepage = "https://github.com/arr-mcps/prowlarr-mcp";
      license = lib.licenses.mit;
      mainProgram = "prowlarr-mcp";
    };
  }
