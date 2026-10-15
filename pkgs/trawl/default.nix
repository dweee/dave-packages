# Native TRAWL API (germondai/trawl). Bun workspace; Camoufox is a separate FOD zip.
# MITM proxy (:8192) is left off — the API listens on PORT (module default 8193).
{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  cacert,
  python3,
  gnumake,
  gcc,
  nodejs,
  node-gyp,
  makeWrapper,
  wrapGAppsHook3,
  autoPatchelfHook,
  gtk3,
  xvfb,
  callPackage,
}: let
  version = "1.4.2-unstable-2026-08-27";
  # Latest tag is v1.4.2 (7189f10); pin `dev` HEAD so GeoLite/Dockerfile pins match.
  src = fetchFromGitHub {
    owner = "germondai";
    repo = "trawl";
    rev = "c0a0d96b0be4bab5953141a693f1bb40a998524a";
    hash = "sha256-bdnrHOaUARQTp+BlYeqX9/AALJ0XUR+htVk29CY6AKM=";
  };

  camoufox-bin = callPackage ./camoufox-bin.nix {};

  betterSqlitePrebuild =
    {
      x86_64-linux = "linux-x64.node";
      aarch64-linux = "linux-arm64.node";
    }.${
      stdenv.hostPlatform.system
    }
    or "linux-x64.node";

  # Network-only: bun install with scripts skipped so the FOD has no store refs
  # from compiled addons. better-sqlite3 is rebuilt in the main derivation.
  nodeModules = stdenv.mkDerivation {
    pname = "trawl-node-modules";
    inherit version src;

    nativeBuildInputs = [bun cacert];

    impureEnvVars = lib.fetchers.proxyImpureEnvVars;

    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    dontConfigure = true;
    dontFixup = true;
    dontPatchShebangs = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash =
      {
        x86_64-linux = "sha256-z631aHTgoYXbqTkM5mZY+hDBFf1v7IkpHoCiM3xh2GA=";
      }.${
        stdenv.hostPlatform.system
      } or (throw "trawl: bun node_modules FOD hash is only recorded for x86_64-linux");

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      bun install --frozen-lockfile --production --omit=dev --linker=hoisted --ignore-scripts
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a node_modules $out/
      # Keep linux-x64-gnu impit only (Dockerfile does the same for unused platforms).
      rm -rf \
        $out/node_modules/impit-linux-arm64-musl \
        $out/node_modules/impit-linux-arm64-gnu \
        $out/node_modules/impit-linux-x64-musl \
        $out/node_modules/impit-darwin-* \
        $out/node_modules/impit-win32-* \
        || true
      runHook postInstall
    '';
  };
in
  stdenv.mkDerivation {
    pname = "trawl";
    inherit version src;

    nativeBuildInputs = [
      bun
      python3
      gnumake
      gcc
      nodejs
      node-gyp
      makeWrapper
      wrapGAppsHook3
      autoPatchelfHook
    ];

    buildInputs = [
      gtk3
      stdenv.cc.cc.lib
    ];

    dontWrapGApps = true;
    dontConfigure = true;
    dontBuild = true;

    # Only patch native addons, not Camoufox (separate drv).
    autoPatchelfIgnoreMissingDeps = [
      "libcuda.so.1"
      "libc.musl-x86_64.so.1"
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/trawl/{apps,packages} $out/bin
      cp package.json bun.lock $out/lib/trawl/
      cp -a packages/types packages/browser packages/tiers $out/lib/trawl/packages/
      cp -a apps/api $out/lib/trawl/apps/
      cp -a ${nodeModules}/node_modules $out/lib/trawl/

      chmod -R u+w $out/lib/trawl

      mkdir -p $out/lib/trawl/node_modules/@trawl
      rm -rf $out/lib/trawl/node_modules/@trawl/types \
             $out/lib/trawl/node_modules/@trawl/browser \
             $out/lib/trawl/node_modules/@trawl/tiers \
             $out/lib/trawl/node_modules/@trawl/api \
             $out/lib/trawl/node_modules/@trawl/web \
             $out/lib/trawl/node_modules/@trawl/docs
      ln -s ../../packages/types $out/lib/trawl/node_modules/@trawl/types
      ln -s ../../packages/browser $out/lib/trawl/node_modules/@trawl/browser
      ln -s ../../packages/tiers $out/lib/trawl/node_modules/@trawl/tiers
      ln -s ../../apps/api $out/lib/trawl/node_modules/@trawl/api

      if [ -d $out/lib/trawl/node_modules/better-sqlite3 ]; then
        (
          cd $out/lib/trawl/node_modules/better-sqlite3
          export HOME=$TMPDIR
          export npm_config_nodedir=${nodejs}
          export npm_config_build_from_source=true
          ${lib.getExe node-gyp} rebuild
        )
      fi

      find $out/lib/trawl/node_modules -path '*/better-sqlite3*/deps' -prune -exec rm -rf {} + || true
      find $out/lib/trawl/node_modules -path '*/better-sqlite3*/src' -prune -exec rm -rf {} + || true
      # Drop unused better-sqlite3 prebuilds (musl/arm/darwin/win) so autoPatchelf
      # does not require libc.musl.
      if [ -d $out/lib/trawl/node_modules/better-sqlite3/prebuilds ]; then
        find $out/lib/trawl/node_modules/better-sqlite3/prebuilds -type f ! -name '${betterSqlitePrebuild}' -delete
      fi
      rm -rf $out/lib/trawl/node_modules/@typescript $out/lib/trawl/node_modules/typescript
      find $out/lib/trawl/node_modules/.bin -type l ! -exec test -e {} \; -delete || true

      makeWrapper ${lib.getExe bun} $out/bin/trawl \
        --add-flags "run" \
        --add-flags "$out/lib/trawl/apps/api/src/index.ts" \
        --chdir "$out/lib/trawl" \
        --prefix PATH : ${lib.makeBinPath [bun xvfb]} \
        --set CAMOUFOX_INSTALL_DIR ${camoufox-bin} \
        --set BUN_DISABLE_CJS 1 \
        --set BUN_DEBUG 0 \
        --set BUN_DISABLE_SOURCEMAPS 1 \
        --set BUN_LOCKFILE_MIGRATION false \
        --set NODE_NO_WARNINGS 1 \
        "''${gappsWrapperArgs[@]}"

      runHook postInstall
    '';

    passthru = {
      inherit camoufox-bin nodeModules;
      srcRev = "c0a0d96b0be4bab5953141a693f1bb40a998524a";
    };

    meta = {
      description = "Self-hosted scraping engine (FlareSolverr-compatible /v1)";
      homepage = "https://github.com/germondai/trawl";
      license = lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "trawl";
    };
  }
