{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  playwright,
  twocaptcha-python-async,
}:
buildPythonPackage rec {
  pname = "playwright-captcha";
  version = "0.1.5";
  pyproject = true;

  src = fetchPypi {
    pname = "playwright_captcha";
    inherit version;
    hash = "sha256-rCt3L5o/wDgb+ycCmBqUA+TQQ2j7pA10j1WwoKEVuc0=";
  };

  build-system = [setuptools];

  # Upstream lists only 2captcha-python-async; __init__.py imports playwright.
  dependencies = [
    playwright
    twocaptcha-python-async
  ];

  pythonImportsCheck = ["playwright_captcha"];

  doCheck = false;

  meta = {
    description = "Captcha solving helpers for Playwright";
    homepage = "https://github.com/techinz/playwright-captcha";
    license = lib.licenses.mit;
  };
}
