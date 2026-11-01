# Horizon's prebuilt release archives, wrapped (the -bin packages).
#
#   kind = "launcher"  horizon-launcher-*.tar.gz / Horizon.app
#   kind = "game"      horizon-<platform>: client, horizon-ctl, prepare, server
#   kind = "server"    horizon-server-linux-x86_64 (engine, prepare, server); on
#                      macOS the game folder, whose server runs the full game
#
# Upstream publishes x86_64 Linux and macOS builds only; ARM Linux builds
# from source (./game.nix with headless = true).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  unzip,
  alsa-lib,
  udev,
  libGL,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  fontconfig,
  freetype,
  openssl,
  wrapFolder,
  kind,
  pin,
}:

let
  system = stdenv.hostPlatform.system;
  assets = if kind == "launcher" then pin.assets else pin.${kind};
  asset = assets.${system} or (throw "horizon ${kind}: no prebuilt build for ${system}");
  linux = stdenv.hostPlatform.isLinux;
  desktopItem = makeDesktopItem {
    name = "horizon-launcher";
    desktopName = "Horizon";
    genericName = "Game launcher";
    comment = "Install, prepare and play Horizon, Minecraft: Java Edition 26.3 rewritten in Rust";
    exec = "horizon-launcher";
    icon = "horizon";
    categories = [ "Game" ];
    startupWMClass = "horizon-launcher";
  };
  headless = kind == "server" && linux;
  runtimeLibraries = [
    libGL
    libxkbcommon
    vulkan-loader
    wayland
    libx11
    libxcb
    libxcursor
    libxi
    libxrandr
  ];
in
stdenv.mkDerivation {
  pname =
    {
      launcher = "horizon-launcher-bin";
      game = "horizon-bin";
      server = "horizon-server-bin";
    }
    .${kind};
  inherit (pin) version;

  src = fetchurl { inherit (asset) url hash; };
  sourceRoot = ".";

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optional linux autoPatchelfHook
  ++ lib.optional (lib.hasSuffix ".zip" asset.url) unzip;

  buildInputs = lib.optionals linux (
    [ stdenv.cc.cc.lib ]
    ++ lib.optionals (kind != "server") [
      alsa-lib
      udev
      fontconfig
      freetype
      openssl
      libxkbcommon
      libxcb
      wayland
    ]
  );

  # The libraries the programs open at run time are added to their rpath.
  autoPatchelfIgnoreMissingDeps = lib.optionals linux [
    "libvulkan.so.1"
    "libwayland-client.so.0"
    "libxkbcommon.so.0"
  ];
  dontStrip = true;

  installPhase =
    if kind == "launcher" then
      if linux then
        ''
          runHook preInstall
          install -Dm755 horizon-launcher $out/bin/horizon-launcher
          # The archive holds only the program: the menu entry upstream's
          # packaging/linux/horizon-launcher.desktop describes.
          install -Dm644 -t $out/share/applications ${desktopItem}/share/applications/*.desktop
          runHook postInstall
        ''
      else
        ''
          runHook preInstall
          mkdir -p $out/Applications $out/bin
          cp -R Horizon.app $out/Applications/
          runHook postInstall
        ''
    else
      ''
        runHook preInstall
        mkdir -p $out/libexec
        cp -R horizon-*/ $out/libexec/horizon
        runHook postInstall
      '';

  postFixup =
    if kind == "launcher" then
      if linux then
        ''
          patchelf --add-rpath ${lib.makeLibraryPath runtimeLibraries} $out/bin/horizon-launcher
          wrapProgram $out/bin/horizon-launcher --set-default HORIZON_LAUNCHER_NO_SELF_UPDATE 1
        ''
      else
        ''
          makeWrapper $out/Applications/Horizon.app/Contents/MacOS/horizon-launcher $out/bin/horizon-launcher \
            --set-default HORIZON_LAUNCHER_NO_SELF_UPDATE 1
        ''
    else
      wrapFolder {
        inherit headless;
        game = if headless then "horizon-engine" else "horizon-client";
        runtimeLibraries = lib.optionals (linux && kind == "game") runtimeLibraries;
      };

  passthru = { inherit pin kind; };

  meta = {
    description =
      {
        launcher = "Launcher for Horizon, Minecraft: Java Edition 26.3 rewritten in Rust (prebuilt)";
        game = "Horizon, Minecraft: Java Edition 26.3 rewritten in Rust (prebuilt)";
        server = "Dedicated server for Horizon, a native Minecraft: Java Edition 26.3 implementation (prebuilt)";
      }
      .${kind};
    homepage = "https://playhorizon.dev";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram =
      {
        launcher = "horizon-launcher";
        game = "horizon-client";
        server = "horizon-server";
      }
      .${kind};
    platforms = builtins.attrNames assets;
  };
}
