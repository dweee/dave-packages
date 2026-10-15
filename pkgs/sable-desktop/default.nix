{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  addDriverRunpath,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  desktop-file-utils,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libayatana-appindicator,
  libdrm,
  libgbm,
  libGL,
  libpulseaudio,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,
  wayland,
  xdg-utils,
}: let
  pname = "sable-desktop";
  version = "1.22.11";

  # Upstream release tarballs (Tauri 2 on CEF, not WebKitGTK). Building from
  # source needs their pinned CEF + fenix toolchain; the web UI is nixpkgs#sable.
  sources = {
    x86_64-linux = {
      url = "https://github.com/SableClient/Sable/releases/download/v${version}/Sable-${version}-linux-x86_64.tar.gz";
      hash = "sha256-gnre7hNvfeB25jgZGLHuBDxq8YS6qHzw/RW7bi90B6w=";
    };
    aarch64-linux = {
      url = "https://github.com/SableClient/Sable/releases/download/v${version}/Sable-${version}-linux-aarch64.tar.gz";
      hash = "sha256-3M5MULzYH2OHKtbq9U9fFf492rwTj5bOD+0zyXNu3y4=";
    };
  };

  # libcef.so's DT_NEEDED set. Rewriting its ELF headers (patchelf or strip)
  # makes CEF init fail and tauri exits with Err(Runtime(CreateWindow)), so
  # only the launcher is patched and the bundled .so files resolve these via
  # LD_LIBRARY_PATH.
  cefLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemdLibs
  ];

  # dlopened at runtime: GL/Vulkan drivers, tray icon, audio for calls.
  runtimeLibs = [
    libGL
    libayatana-appindicator
    libdrm
    libpulseaudio
    pipewire
    wayland
  ];
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl sources.${stdenv.hostPlatform.system};

    sourceRoot = ".";

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = [
      gdk-pixbuf
      glib
      gtk3
      stdenv.cc.cc.lib
    ];

    dontConfigure = true;
    dontBuild = true;
    dontWrapGApps = true;
    dontStrip = true;
    dontPatchELF = true;
    dontAutoPatchelf = true;

    # Same flat layout as the upstream .deb (/opt/sable): the binary has
    # RUNPATH=$ORIGIN and expects libcef.so and its .pak files beside it.
    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/sable $out/bin
      cp -r runtime/. $out/lib/sable/
      install -Dm755 sable $out/lib/sable/sable
      cp -r share $out/share

      runHook postInstall
    '';

    # The deep-link setup hook runs update-desktop-database and panics
    # (os error 2) when it is missing.
    postFixup = ''
      addAutoPatchelfSearchPath $out/lib/sable
      autoPatchelf $out/lib/sable/sable
      makeWrapper $out/lib/sable/sable $out/bin/sable \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (cefLibs ++ runtimeLibs)}:${addDriverRunpath.driverLink}/lib \
        --prefix PATH : ${lib.makeBinPath [desktop-file-utils xdg-utils]}
    '';

    meta = {
      description = "Matrix client forked from Cinny (Tauri desktop build)";
      homepage = "https://sable.moe";
      changelog = "https://github.com/SableClient/Sable/releases/tag/v${version}";
      license = lib.licenses.agpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = builtins.attrNames sources;
      mainProgram = "sable";
    };
  }
