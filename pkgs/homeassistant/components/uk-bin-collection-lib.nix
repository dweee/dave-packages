{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  home-assistant,
}: let
  pyPkgs = home-assistant.python3Packages;
  pdfplumber = pyPkgs.pdfplumber.overridePythonAttrs (_: {
    doCheck = false;
    nativeCheckInputs = [];
  });
in
  buildPythonPackage rec {
    pname = "uk-bin-collection";
    version = "0.173.5";

    src = fetchFromGitHub {
      owner = "robbrad";
      repo = "UKBinCollectionData";
      rev = version;
      hash = "sha256-6s5ZA2Hkm9MTCTn8+50991ztH30ncnm0FBgbPQKkJTs=";
    };

    pyproject = true;

    build-system = [
      pyPkgs.poetry-core
    ];

    # Upstream wheel metadata names/constraints do not line up with nixpkgs:
    # - `bs4` is provided by `beautifulsoup4`
    # - nixpkgs currently has `icalevents` 0.3.1
    # - Home Assistant's Python package set has `curl-cffi` 0.16.0
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'bs4 = "*"' 'beautifulsoup4 = "*"' \
        --replace-fail 'icalevents = "^0.2.1"' 'icalevents = ">=0.2.1"' \
        --replace-fail 'curl_cffi = "^0.16.3"' 'curl_cffi = ">=0.16.0,<0.17.0"'

      # North Northants CMS can stall; requests.get had no timeout so HA's
      # 60s coordinator wait_for always lost to a hung socket.
      substituteInPlace uk_bin_collection/uk_bin_collection/councils/NorthNorthamptonshireCouncil.py \
        --replace-fail 'headers=headers,' 'headers=headers, timeout=30,'
    '';

    dependencies = [
      pyPkgs.beautifulsoup4
      pyPkgs."python-dateutil"
      pyPkgs.curl-cffi
      pyPkgs.holidays
      pyPkgs.icalevents
      pyPkgs.lxml
      pyPkgs.pandas
      pdfplumber
      pyPkgs.requests
      pyPkgs.selenium
      pyPkgs.tabulate
      pyPkgs.undetected-chromedriver
      pyPkgs.urllib3
      pyPkgs."webdriver-manager"
    ];

    # Wheel metadata pins tabulate<0.10; nixpkgs ships 0.10.0.
    pythonRelaxDeps = ["tabulate"];

    pythonImportsCheck = [
      "uk_bin_collection"
    ];

    doCheck = false;

    meta = with lib; {
      homepage = "https://github.com/robbrad/UKBinCollectionData";
      license = licenses.mit;
      description = "Python library for UK council bin collection data (used by the Home Assistant integration).";
    };
  }
