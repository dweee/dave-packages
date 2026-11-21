{
  lib,
  writeShellApplication,
  pythonPackages,
  src,
}:
let
  pythonEnv = pythonPackages.python.withPackages (_: [
    pythonPackages.fastmcp
    pythonPackages.httpx
  ]);
in
writeShellApplication {
  name = "prowlarr-mcp";
  runtimeInputs = [ pythonEnv ];
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
