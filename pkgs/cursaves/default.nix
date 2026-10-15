{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication rec {
  pname = "cursaves";
  version = "0-unstable-2026-05-14";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Callum-Ward";
    repo = "cursaves";
    # Upstream has no git tags; pin the v0.9.1 commit on main.
    rev = "2919739d35a043f1f35979a758f87d4c936a42b7";
    hash = "sha256-XTsOpCZVMxl88ErI0uUsgZf1O/FX+mREu4j1kiIfhqg=";
  };

  build-system = [python3Packages.hatchling];

  dependencies = [python3Packages.inquirerpy];

  patches = [./cursaves-dir.patch];

  pythonImportsCheck = ["cursor_saves" "cursor_saves.paths"];

  meta = {
    description = "Export and restore Cursor agent chat sessions";
    homepage = "https://github.com/Callum-Ward/cursaves";
    license = lib.licenses.agpl3Only;
    mainProgram = "cursaves";
    platforms = lib.platforms.unix;
  };
}
