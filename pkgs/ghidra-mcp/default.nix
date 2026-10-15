{
  lib,
  writeShellApplication,
  python3,
  stdenvNoCC,
  fetchurl,
  unzip,
  src,
}: let
  version = "6.0.0";
  pythonEnv = python3.withPackages (ps: [
    ps.mcp
    ps.starlette
    ps.uvicorn
  ]);
  extension = stdenvNoCC.mkDerivation {
    pname = "ghidra-mcp-extension";
    inherit version;
    src = fetchurl {
      url = "https://github.com/bethington/ghidra-mcp/releases/download/v${version}/GhidraMCP-${version}.zip";
      hash = "sha256-hncx3ifVFDYyoBCUO5B6ZIXdVNDhlyni+F7p9pLJmHM=";
    };
    nativeBuildInputs = [unzip];
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/ghidra/Ghidra/Extensions"
      unzip -q "$src" -d "$TMPDIR/ext"
      if [ -d "$TMPDIR/ext/GhidraMCP" ]; then
        mv "$TMPDIR/ext/GhidraMCP" "$out/lib/ghidra/Ghidra/Extensions/"
      else
        mkdir -p "$out/lib/ghidra/Ghidra/Extensions/GhidraMCP"
        mv "$TMPDIR/ext"/* "$out/lib/ghidra/Ghidra/Extensions/GhidraMCP/"
      fi
      # Upstream ships Module.manifest as simple key/value metadata.
      # Ghidra expects either an empty manifest or directive-style entries.
      : > "$out/lib/ghidra/Ghidra/Extensions/GhidraMCP/Module.manifest"
      touch "$out/lib/ghidra/Ghidra/Extensions/GhidraMCP/.dbDirLock"
      runHook postInstall
    '';
    meta = {
      description = "GhidraMCP plugin (HTTP backend for the Python MCP bridge)";
      homepage = "https://github.com/bethington/ghidra-mcp";
      license = lib.licenses.asl20;
      sourceProvenance = with lib.sourceTypes; [binaryBytecode];
    };
  };
in
  (writeShellApplication {
    name = "ghidra-mcp";
    runtimeInputs = [pythonEnv];
    text = ''
      export PYTHONPATH=${src}/python''${PYTHONPATH:+:$PYTHONPATH}
      export GHIDRA_MCP_URL="''${GHIDRA_MCP_URL:-http://127.0.0.1:8089}"
      exec python -m bridge_mcp_ghidra --transport stdio "$@"
    '';
    meta = {
      description = "MCP stdio bridge to a running GhidraMCP HTTP server";
      homepage = "https://github.com/bethington/ghidra-mcp";
      license = lib.licenses.asl20;
      mainProgram = "ghidra-mcp";
    };
  }).overrideAttrs (_: {
    passthru = {inherit extension;};
  })
