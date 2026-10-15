# Prebuilt stealth Firefox for invisible-playwright. autoPatchelf so libxul/XPCOM
# resolve against nixpkgs glibc (upstream tarball is a FHS layout).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  patchelfUnstable,
  wrapGAppsHook3,
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
  assets = {
    x86_64-linux = {
      url = "https://github.com/feder-cr/firefox_antidetect_patch/releases/download/firefox-20/firefox-151.0-stealth-linux-x86_64.tar.gz";
      hash = "sha256-1WWIgMv41sNPjXEEOhiscujKWilpKOtffvnjKkZR2IQ=";
      cacheName = "firefox-20_151.0_20260817150018";
    };
    aarch64-linux = {
      url = "https://github.com/feder-cr/firefox_antidetect_patch/releases/download/firefox-20/firefox-151.0-stealth-linux-arm64.tar.gz";
      hash = "sha256-HtWeTLvqbAxDB5kBXcuyW1vLY+JxqJQ45VqwpBufmLY=";
      cacheName = "firefox-20_151.0_20260817145957";
    };
  };

  asset =
    assets.${stdenv.hostPlatform.system}
    or (throw "stealth-firefox: no binary for ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    pname = "stealth-firefox";
    version = "151.0";

    src = fetchurl {
      inherit (asset) url hash;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      patchelfUnstable
      wrapGAppsHook3
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

    appendRunpaths = ["${pipewire}/lib"];

    patchelfFlags = ["--no-clobber-old-sections"];

    autoPatchelfIgnoreMissingDeps = [
      "libcuda.so.1"
    ];

    dontStrip = true;

    # wrapGApp the launcher so libgtk-3 and GdkPixbuf loaders are visible.
    # Playwright execs $out/firefox, not a bin/ wrapper.
    dontWrapGApps = true;

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      if [ -e firefox/firefox ] || [ -e firefox/firefox-bin ]; then
        cp -a firefox/. $out/
      else
        cp -a . $out/
        rm -f $out/env-vars
      fi
      chmod -R u+w $out
      find $out -type f \( -name firefox -o -name firefox-bin \) -exec chmod 755 {} +
      test -e $out/firefox || test -e $out/firefox-bin
      runHook postInstall
    '';

    preFixup = ''
      wrapGApp "$out/firefox"
    '';

    passthru = {
      inherit (asset) cacheName;
    };

    meta = {
      description = "Patched stealth Firefox 151 for invisible-playwright";
      homepage = "https://github.com/feder-cr/firefox_antidetect_patch";
      license = lib.licenses.mpl20;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = lib.attrNames assets;
    };
  }
