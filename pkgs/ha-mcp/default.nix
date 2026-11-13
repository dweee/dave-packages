{ ha-mcp, fetchFromGitHub }:
let
  skills = fetchFromGitHub {
    owner = "homeassistant-ai";
    repo = "skills";
    rev = "bc73bdac9f2be4b7e62bb3fcfe8b826050dcf851";
    hash = "sha256-IgZfwQDH36McOJMdrmEOwGOiEg94Nem7aBuHYHckSz4=";
  };
in
ha-mcp.overridePythonAttrs (old: {
  # Application changes retain upstream ancestry in the compatibility fork;
  # packaging, native tests and cache publication remain catalog-owned.
  version = "9.1.0";
  src = fetchFromGitHub {
    owner = "dweee";
    repo = "ha-mcp";
    rev = "dafcd92758c096a7cf3b7e871f605386c2d198ba";
    hash = "sha256-PWigODTiJ43vcb9DThUCsPZOf+HC5tl836hupOLHAis=";
  };
  patches = (old.patches or [ ]) ++ [
    ./guidance-platform-tests.patch
    ./json-decoder-recursion-test.patch
    ./wildcard-port-test-fixtures.patch
  ];
  postPatch = (old.postPatch or "") + ''
    mkdir -p src/ha_mcp/resources
    cp -a ${skills}/. src/ha_mcp/resources/skills-vendor/
  '';
})
