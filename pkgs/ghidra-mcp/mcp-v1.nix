# SDK version declared by the frozen GhidraMCP 7 source (pyproject.toml).
{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  uv-dynamic-versioning,
  anyio,
  httpx,
  httpx-sse,
  jsonschema,
  pydantic-settings,
  pydantic,
  pyjwt,
  python-multipart,
  sse-starlette,
  starlette,
  typing-extensions,
  typing-inspection,
  uvicorn,
}:
buildPythonPackage rec {
  pname = "mcp";
  version = "1.28.1";
  pyproject = true;
  src = fetchPypi {
    inherit pname version;
    hash = "sha256-1R42pfVkT66k+F6mSb//prxsJncNQnmK1qPePSumloM=";
  };
  build-system = [
    hatchling
    uv-dynamic-versioning
  ];
  dependencies = [
    anyio
    httpx
    httpx-sse
    jsonschema
    pydantic-settings
    pydantic
    pyjwt
    python-multipart
    sse-starlette
    starlette
    typing-extensions
    typing-inspection
    uvicorn
  ]
  ++ pyjwt.optional-dependencies.crypto;
  pythonImportsCheck = [
    "mcp"
    "mcp.server.fastmcp"
    "mcp.server.transport_security"
  ];
  meta = {
    description = "Model Context Protocol 1.x SDK for GhidraMCP 7";
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = lib.licenses.mit;
  };
}
