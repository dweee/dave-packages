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
  name = "slskd-mcp";
  runtimeInputs = [ pythonEnv ];
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
