# Camoufox Firefox binary (not built from source). Pins match germondai/trawl
# apps/api/Dockerfile: v152.0.4-beta.28 plus baked GeoLite2-City and uBlock Origin
# so camoufox-js does not fetch those at runtime.
{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  patchelfUnstable,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  cups,
  dbus,
  dbus-glib,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libva,
  libxkbcommon,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  curl,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  libxcb,
}: let
  version = "152.0.4-beta.28";

  camoufoxAssets = {
    x86_64-linux = {
      zip = "camoufox-152.0.4-beta.28-lin.x86_64.zip";
      hash = "sha256-kk8xCczW1HzWoDhNZ6NF+t+XXUi2MZ+Nu9WVTFiJgr0=";
    };
    aarch64-linux = {
      zip = "camoufox-152.0.4-beta.28-lin.arm64.zip";
      hash = "sha256-OhBaL8kp6Ap5tLf84sk+1ixPssh388HtKl1mocT+lo8=";
    };
  };

  asset =
    camoufoxAssets.${stdenv.hostPlatform.system}
    or (throw "camoufox-bin: unsupported system ${stdenv.hostPlatform.system}");

  geoip = fetchurl {
    name = "GeoLite2-City.mmdb";
    url = "https://github.com/P3TERX/GeoLite.mmdb/releases/download/2026.09.19/GeoLite2-City.mmdb";
    hash = "sha256-mkT8OiHwE6INMJgDiva41t5F2K4iOFyUzXcj7hoOAOU=";
  };

  ublockOrigin = fetchurl {
    name = "ublock_origin-1.73.0.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4940584/ublock_origin-1.73.0.xpi";
    hash = "sha256-vMxRp3MVCvSvbh/WLHv963I4t5/yOBuZj6ny449keGo=";
  };
in
  stdenv.mkDerivation {
    pname = "camoufox-bin";
    inherit version;

    src = fetchurl {
      name = asset.zip;
      url = "https://github.com/daijro/camoufox/releases/download/v${version}/${asset.zip}";
      inherit (asset) hash;
    };

    nativeBuildInputs = [
      unzip
      autoPatchelfHook
      patchelfUnstable
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      atk
      cairo
      cups
      dbus
      dbus-glib
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libGL
      libxkbcommon
      nspr
      nss
      pango
      stdenv.cc.cc.lib
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
      libxcb
    ];

    runtimeDependencies = [
      curl
      libva.out
      pciutils
    ];

    appendRunpaths = [
      "${pipewire}/lib"
    ];

    # Firefox uses relrhack; clobbering PT_NOTE breaks the binary.
    patchelfFlags = ["--no-clobber-old-sections"];

    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      mkdir -p source
      unzip -q "$src" -d source
      runHook postUnpack
    '';

    sourceRoot = "source";

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -a . $out/

      printf '{"version":"152.0.4","release":"beta.28"}\n' > $out/version.json

      cp ${geoip} $out/GeoLite2-City.mmdb

      mkdir -p $out/addons/UBO
      unzip -q ${ublockOrigin} -d $out/addons/UBO
      test -f $out/addons/UBO/manifest.json

      rm -rf $out/fonts/macos $out/fonts/windows

      chmod -R u+w $out
      find $out -type f \( -name camoufox-bin -o -name firefox -o -name firefox-bin -o -name camoufox \) -exec chmod 755 {} +

      runHook postInstall
    '';

    # CAMOUFOX_INSTALL_DIR is this output; camoufox-js execs $out/camoufox-bin (ELF, not a wrapper).
    passthru = {
      geoipRelease = "2026.09.19";
      ublockVersion = "1.73.0";
    };

    meta = {
      description = "Camoufox Firefox binary with baked GeoLite2-City and uBlock Origin";
      homepage = "https://github.com/daijro/camoufox";
      license = lib.licenses.mpl20;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = lib.attrNames camoufoxAssets;
    };
  }
