{
  ha-mcp,
  fetchFromGitHub,
  fetchpatch,
}:
let
  skills = fetchFromGitHub {
    owner = "homeassistant-ai";
    repo = "skills";
    rev = "bc73bdac9f2be4b7e62bb3fcfe8b826050dcf851";
    hash = "sha256-IgZfwQDH36McOJMdrmEOwGOiEg94Nem7aBuHYHckSz4=";
  };
in
ha-mcp.overridePythonAttrs (old: {
  # Keep nixpkgs' release source, including its bundled skill content.
  # Application changes are reviewed in the ancestry-preserving source fork.
  patches = (old.patches or [ ]) ++ [
    ./guidance-platform-tests.patch
    ./json-decoder-recursion-test.patch
    ./wildcard-port-test-fixtures.patch
    (fetchpatch {
      name = "ha-mcp-9.1.0-listener-order.patch";
      url = "https://github.com/dweee/ha-mcp/compare/d2e3f4b0647d815fb32d530fed15a6a99b1d4b33...dafcd92758c096a7cf3b7e871f605386c2d198ba.diff";
      hash = "sha256-CkApsaUzZ02ZGKhieEyC46VXhGM+KQOR/XvsbwlXTjQ=";
    })
  ];
  postPatch = (old.postPatch or "") + ''
    mkdir -p src/ha_mcp/resources
    cp -a ${skills}/. src/ha_mcp/resources/skills-vendor/
  '';
})
