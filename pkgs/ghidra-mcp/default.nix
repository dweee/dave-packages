{
  lib,
  writeShellApplication,
  python3,
  ghidra,
  writeText,
  src,
}:
let
  version = "7.0.0";
  # Version 7 explicitly supports MCP 1.x. Keep its declared SDK instead of
  # changing application code to the unrelated 2.x API.
  mcp1 = python3.pkgs.callPackage ./mcp-v1.nix { };
  pythonEnv = python3.withPackages (ps: [
    mcp1
    ps.starlette
    ps.uvicorn
  ]);
  # The upstream ZIP targets Ghidra 12.1.4. Compile against the exact catalog
  # Ghidra instead, so extension metadata and Java APIs are checked together.
  extension = ghidra.buildGhidraExtension {
    pname = "GhidraMCP";
    inherit version src;
    gradleFlags = [
      "--offline"
      "--no-daemon"
      "--max-workers=2"
      "-PGHIDRA_INSTALL_DIR=${ghidra}/lib/ghidra"
      "--init-script"
      (writeText "ghidra-mcp-jdk.gradle" ''
        allprojects {
          plugins.withId('java') {
            afterEvaluate {
              java.toolchain.languageVersion = JavaLanguageVersion.of(25)
            }
          }
        }
      '')
    ];
    postPatch = ''
      # Upstream's build timestamp otherwise makes the archive non-reproducible.
      substituteInPlace build.gradle \
        --replace-fail "new Date().format('yyyyMMdd-HHmmss')" "new Date(0).format('yyyyMMdd-HHmmss', TimeZone.getTimeZone('UTC'))"
    '';
    env.TZ = "UTC";
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/ghidra/Ghidra/Extensions"
      unzip -q build/distributions/GhidraMCP-${version}.zip \
        -d "$out/lib/ghidra/Ghidra/Extensions"
      grep -Fx 'version=${ghidra.version}' \
        "$out/lib/ghidra/Ghidra/Extensions/GhidraMCP/extension.properties"
      touch "$out/lib/ghidra/Ghidra/Extensions/GhidraMCP/.dbDirLock"
      runHook postInstall
    '';
    meta = {
      description = "GhidraMCP plugin compiled against the catalog Ghidra";
      homepage = "https://github.com/bethington/ghidra-mcp";
      license = lib.licenses.asl20;
    };
  };
in
(writeShellApplication {
  name = "ghidra-mcp";
  runtimeInputs = [ pythonEnv ];
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
}).overrideAttrs
  (_: {
    passthru = { inherit extension; };
  })
