{
  lib,
  python3,
  fetchFromGitHub,
}:
# SlopBro ships as a single stdlib-only Python script plus a wwwroot/ directory
# of exploit/payload assets. Upstream's own `tools/package_single_file.py`
# embeds wwwroot into the script as base64 JSON so the result is one
# self-contained file with no runtime asset path to resolve. We run that
# packager at build time and install the packed script as `bin/slopbro`.
python3.pkgs.buildPythonApplication rec {
  pname = "slopbro";
  version = "0.1.0-unstable-2026-09-28";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "throwaway96";
    repo = "slopbro";
    rev = "21023d56ca424607bb03d2939609cc658c655fc7";
    hash = "sha256-jByJQiKYyiY0z9FnYM3xeKVH+rsibh6mF+E0keSIrF4=";
  };

  # No third-party deps; stdlib only (and pyproject = false, so no build-system).
  dontWrapPythonPrograms = true;

  configurePhase = "runHook preConfigure runHook postConfigure";
  buildPhase = ''
    runHook preBuild
    python3 tools/package_single_file.py \
      --source slopbro.py \
      --wwwroot wwwroot \
      --out dist/slopbro_packed.py
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 dist/slopbro_packed.py $out/bin/slopbro
    runHook postInstall
  '';

  pythonImportsCheck = [];

  meta = {
    description = "PoC exploit for the jsserver vulnerability in LG webOS TVs (Homebrew Channel autoroot)";
    homepage = "https://github.com/throwaway96/slopbro";
    license = lib.licenses.agpl3Only;
    mainProgram = "slopbro";
    # Pure stdlib; runs anywhere CPython 3 does.
    platforms = lib.platforms.unix;
  };
}
