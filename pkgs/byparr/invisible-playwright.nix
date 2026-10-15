{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  invisible-core,
  playwright,
  psutil,
}:
buildPythonPackage rec {
  pname = "invisible-playwright";
  version = "0.7.2";
  pyproject = true;

  src = fetchPypi {
    pname = "invisible_playwright";
    inherit version;
    hash = "sha256-PxoZuvYv/26aG/CzXr5JWI88EldoDrszz6lI8RUnh6Q=";
  };

  build-system = [hatchling];

  pythonRelaxDeps = ["playwright"];

  # nixpkgs playwright is 1.63; stealth Firefox seal is 1.55–1.61. Import-time
  # assert otherwise fails pythonImportsCheck. Runtime wrap sets the same.
  env.INVISIBLE_PLAYWRIGHT_SKEW = "allow";

  dependencies = [
    invisible-core
    playwright
    psutil
  ];

  pythonImportsCheck = ["invisible_playwright"];

  doCheck = false;

  meta = {
    description = "Playwright wrapper for a patched stealth Firefox";
    homepage = "https://github.com/feder-cr/invisible_playwright";
    license = lib.licenses.mit;
  };
}
