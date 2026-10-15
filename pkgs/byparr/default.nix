{
  lib,
  python313Packages,
  fetchFromGitHub,
  fetchurl,
  playwright-driver,
  xvfb-run,
  xvfb,
  unzip,
  callPackage,
}: let
  inherit (python313Packages) python;
  # WebKit on this pin fails auto-patchelf (libmanette). Byparr uses stealth
  # Firefox + Chromium, not WPE WebKit.
  playwrightBrowsers = playwright-driver.browsers.override {withWebkit = false;};

  stealthFirefox = callPackage ./stealth-firefox.nix {};

  geoipMmdbZip = fetchurl {
    url = "https://github.com/daijro/geoip-all-in-one/releases/download/2026.09.30/geoip-aio-all.mmdb.zip";
    hash = "sha256-Ca9EjlHi8BLIfkreGzn5P5mcMrpiBec+JbmOMDPPle4=";
  };

  invisible-core = python313Packages.callPackage ./invisible-core.nix {};

  invisible-playwright = python313Packages.callPackage ./invisible-playwright.nix {
    inherit invisible-core;
  };

  twocaptcha-python-async = python313Packages.callPackage ./twocaptcha-python-async.nix {};

  playwright-captcha = python313Packages.callPackage ./playwright-captcha.nix {
    inherit twocaptcha-python-async;
  };
in
  python313Packages.buildPythonApplication rec {
    pname = "byparr";
    version = "3.0.4";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "ThePhaseless";
      repo = "Byparr";
      rev = "v${version}";
      hash = "sha256-coyi6e0dEy31gaiX8Mx+0pPZAI0eDNq1f+zrUqu3bVk=";
    };

    # Upstream is `uv run main.py` with no build-system or console script.
    postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-fail 'playwright==1.60.*' 'playwright>=1.60'

            cat >> pyproject.toml <<'EOF'

      [build-system]
      requires = ["hatchling"]
      build-backend = "hatchling.build"

      [project.scripts]
      byparr = "main:main"

      [tool.hatch.build.targets.wheel]
      packages = ["src"]

      [tool.hatch.build.targets.wheel.force-include]
      "main.py" = "main.py"
      EOF

            touch src/__init__.py

            python -c '
      from pathlib import Path

      main = Path("main.py")
      text = main.read_text()
      needle = "if __name__ == \"__main__\":"
      if needle not in text:
          raise SystemExit("main.py entry block missing; update pkgs/byparr/default.nix")
      main.write_text(text.replace(needle, "def main() -> None:", 1) + "\n\nif __name__ == \"__main__\":\n    main()\n")

      utils = Path("src/utils.py")
      u = utils.read_text()
      if "from collections.abc import AsyncGenerator" not in u:
          raise SystemExit("src/utils.py import block missing; update pkgs/byparr/default.nix")
      if "import os" not in u.split("from collections.abc", 1)[0]:
          u = u.replace("from collections.abc import AsyncGenerator", "import os\nfrom collections.abc import AsyncGenerator", 1)
      old = "async with InvisiblePlaywright(\n        headless=True,"
      new = "async with InvisiblePlaywright(\n        binary_path=os.environ.get(\"INVPW_BINARY_PATH\") or None,\n        headless=True,"
      if old not in u:
          raise SystemExit("InvisiblePlaywright() launch site missing; update pkgs/byparr/default.nix")
      utils.write_text(u.replace(old, new, 1))
      '
    '';

    build-system = [python313Packages.hatchling];

    nativeBuildInputs = [unzip];

    # The extraction API used by src/owui.py is also available in 2.3.
    pythonRelaxDeps = ["playwright" "trafilatura"];

    dependencies =
      [
        python313Packages.fastapi
        python313Packages.pydantic-settings
        python313Packages.playwright
        python313Packages.trafilatura
        invisible-playwright
        playwright-captcha
      ]
      ++ (
        python313Packages.fastapi.optional-dependencies.standard
        or [
          python313Packages.uvicorn
          python313Packages.httpx
          python313Packages.jinja2
          python313Packages.python-multipart
          python313Packages.email-validator
          python313Packages.pydantic-extra-types
        ]
      );

    pythonImportsCheck = ["src.consts" "src.owui"];
    # Use the same explicit skew allowance as the installed runtime wrapper.
    INVISIBLE_PLAYWRIGHT_SKEW = "allow";

    doCheck = false;

    makeWrapperArgs = [
      "--set"
      "PLAYWRIGHT_BROWSERS_PATH"
      "${playwrightBrowsers}"
      "--set"
      "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD"
      "1"
      "--set"
      "PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS"
      "true"
      "--set"
      "INVISIBLE_PLAYWRIGHT_SKEW"
      "allow"
      "--set"
      "INVPW_BINARY_PATH"
      "${stealthFirefox}/firefox"
      "--set-default"
      "INVISIBLE_PLAYWRIGHT_CACHE_DIR"
      "${placeholder "out"}/share/byparr/engine"
      "--set"
      "STEALTHFOX_GEOIP_MMDB"
      "${placeholder "out"}/share/byparr/geoip/geoip-aio-all.mmdb"
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [xvfb-run xvfb])
    ];

    postInstall = ''
            engineDir="$out/share/byparr/engine/${stealthFirefox.passthru.cacheName}"
            mkdir -p "$engineDir"
            cp -a ${stealthFirefox}/. "$engineDir/"
            chmod -R u+w "$engineDir"
            chmod +x "$engineDir/firefox" "$engineDir/firefox-bin" 2>/dev/null || true

            ${python.withPackages (_: [invisible-core])}/bin/python - "$engineDir" <<'PY'
      import platform
      import sys
      from pathlib import Path
      from invisible_core.seal import active_seal, write_stamp

      version_dir = Path(sys.argv[1])
      seal = active_seal()
      asset = seal.asset_for(sys.platform, platform.machine())
      entry = version_dir / asset.entry_rel
      if not entry.exists():
          raise SystemExit(f"stealth Firefox entry missing: {entry}")
      write_stamp(version_dir, seal, asset=asset.name, asset_sha256=asset.sha256, adopted=False)
      print(f"stamped {version_dir} -> {entry}")
      PY

            mkdir -p "$out/share/byparr/geoip"
            unzip -qo ${geoipMmdbZip} -d "$out/share/byparr/geoip"
            test -f "$out/share/byparr/geoip/geoip-aio-all.mmdb"
    '';

    # Keep the patched Firefox tree out of patchelf/strip; it is a prebuilt
    # dist/bin layout, not something Nix should rewrite.
    preFixup = ''
      mv "$out/share/byparr/engine" "$NIX_BUILD_TOP/byparr-engine"
    '';
    postFixup = ''
      mkdir -p "$out/share/byparr"
      mv "$NIX_BUILD_TOP/byparr-engine" "$out/share/byparr/engine"
    '';

    passthru = {
      inherit invisible-core invisible-playwright playwright-captcha stealthFirefox playwrightBrowsers;
    };

    meta = {
      description = "FlareSolverr-compatible API for Cloudflare challenge cookies";
      homepage = "https://github.com/ThePhaseless/Byparr";
      license = lib.licenses.gpl3Only;
      mainProgram = "byparr";
      platforms = lib.platforms.linux;
    };
  }
