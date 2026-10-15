{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  aiofiles,
  httpx,
  requests,
}:
buildPythonPackage rec {
  pname = "2captcha-python-async";
  version = "1.5.1";
  pyproject = true;

  src = fetchPypi {
    pname = "2captcha_python_async";
    inherit version;
    hash = "sha256-ydW3PdrCOovNwblrB19xZZRcDXmDb4Nw04AtnFirMjY=";
  };

  build-system = [setuptools];

  dependencies = [
    aiofiles
    httpx
    requests
  ];

  pythonImportsCheck = ["twocaptcha"];

  doCheck = false;

  meta = {
    description = "Async Python client for the 2Captcha API";
    homepage = "https://github.com/techinz/2captcha-python-async";
    license = lib.licenses.mit;
  };
}
