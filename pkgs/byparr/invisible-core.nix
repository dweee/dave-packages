{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  maxminddb,
  platformdirs,
  psutil,
  pysocks,
  requests,
  tzdata,
}:
buildPythonPackage rec {
  pname = "invisible-core";
  version = "20.15.0";
  pyproject = true;

  src = fetchPypi {
    pname = "invisible_core";
    inherit version;
    hash = "sha256-oL3p3t+TpklC5Uv1IR55ld3ay36Uy2qAY1F3KIvFJcI=";
  };

  build-system = [hatchling];

  dependencies = [
    maxminddb
    platformdirs
    psutil
    pysocks
    requests
    tzdata
  ];

  pythonImportsCheck = ["invisible_core"];

  doCheck = false;

  meta = {
    description = "Stealth Firefox profile config, engine download, proxy, and geo for invisible-playwright";
    homepage = "https://github.com/feder-cr/invisible_core";
    license = lib.licenses.mit;
  };
}
