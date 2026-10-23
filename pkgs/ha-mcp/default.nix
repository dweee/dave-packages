{ ha-mcp, fetchFromGitHub }:
let
  skills = fetchFromGitHub {
    owner = "homeassistant-ai";
    repo = "skills";
    rev = "bc73bdac9f2be4b7e62bb3fcfe8b826050dcf851";
    hash = "sha256-IgZfwQDH36McOJMdrmEOwGOiEg94Nem7aBuHYHckSz4=";
  };
in ha-mcp.overridePythonAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    mkdir -p src/ha_mcp/resources
    cp -a ${skills}/. src/ha_mcp/resources/skills-vendor/
  '';
})
