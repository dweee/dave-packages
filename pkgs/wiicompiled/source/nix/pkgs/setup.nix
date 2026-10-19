{
  lib,
  stdenv,
  buildDotnetModule,
  dotnetCorePackages,
  makeDesktopItem,
  copyDesktopItems,
  writeShellScript,
  clang,
  lld,
  cmake,
  ninja,
  pkg-config,
  vulkan-headers,
  vulkan-loader,
  wayland,
  libxkbcommon,
  libGL,
  libusb1,
  dbus,
  udev,
  openssl,
  zlib,
  src,
  wiicompiled-translator,
  wiicompiled-nodtool,
}: let
  setupUnwrapped = buildDotnetModule {
    pname = "wiicompiled-setup-unwrapped";
    version = "0.2.32";
    inherit src;
    projectFile = "Launcher/WiiCompiled.Setup.Linux/WiiCompiled.Setup.Linux.csproj";
    nugetDeps = ./nuget-deps.nix;
    dotnet-sdk = dotnetCorePackages.sdk_8_0;
    dotnet-runtime = dotnetCorePackages.runtime_8_0;
    executables = ["WiiCompiled.Setup.Linux"];
  };

  pkgConfigPath = lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
    vulkan-headers
    vulkan-loader
    wayland
    libxkbcommon
    libGL
    libusb1
    dbus
    udev
    openssl
    zlib
  ];
in
  stdenv.mkDerivation rec {
    pname = "wiicompiled-setup";
    version = "0.2.32";
    inherit src;

    nativeBuildInputs = [copyDesktopItems];

    desktopItems = [
      (makeDesktopItem {
        name = "wiicompiled-setup";
        desktopName = "WiiCompiled Setup";
        exec = "wiicompiled-setup";
        comment = "Translate, compile, and launch Mario Kart Wii natively";
        categories = ["Game"];
        terminal = true;
      })
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      share=$out/share/wiicompiled
      mkdir -p $share/Launcher $out/bin

      cp -a runtime aurora-main projects $share/
      cp Launcher/local-build.sh $share/Launcher/local-build.sh
      chmod +x $share/Launcher/local-build.sh

      find $share/aurora-main/extern -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
      rm -rf $share/runtime/build

      printf '%s\n' "$out" > $share/.bundle-version

      substitute ${wrapper} $out/bin/wiicompiled-setup \
        --subst-var-by share "$share"
      chmod +x $out/bin/wiicompiled-setup

      runHook postInstall
    '';

    wrapper = writeShellScript "wiicompiled-setup-wrapper" ''
      set -euo pipefail
      bundle=@share@
      cache="''${XDG_DATA_HOME:-$HOME/.local/share}/WiiCompiled/workspace"
      sync=1
      for arg in "$@"; do
        case "$arg" in
          --help|-h|--version) sync=0 ;;
          install|uninstall|launch-base|launch-retro|check-products) sync=1; break ;;
        esac
      done
      if [ "$#" -eq 0 ]; then sync=0; fi
      if [ "$sync" -eq 1 ]; then
        if [ ! -f "$cache/.bundle-version" ] || \
           [ "$(cat "$bundle/.bundle-version")" != "$(cat "$cache/.bundle-version")" ]; then
          mkdir -p "$cache/Launcher"
          for dir in runtime aurora-main projects; do
            rm -rf "$cache/$dir"
            cp -a "$bundle/$dir" "$cache/$dir"
          done
          cp "$bundle/Launcher/local-build.sh" "$cache/Launcher/local-build.sh"
          cp "$bundle/.bundle-version" "$cache/.bundle-version"
        fi
      fi
      export PATH=${lib.makeBinPath [pkg-config clang lld cmake ninja]}''${PATH:+:$PATH}
      export PKG_CONFIG_PATH=${pkgConfigPath}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
      exec ${setupUnwrapped}/bin/WiiCompiled.Setup.Linux \
        --workspace "$cache" \
        --translator-bin ${wiicompiled-translator}/bin/Translator.Cli \
        --disc-tool-bin ${wiicompiled-nodtool}/bin/nodtool \
        --cc ${clang}/bin/clang \
        --cxx ${clang}/bin/clang++ \
        --fuse-ld ${lld}/bin/ld.lld \
        --cmake ${cmake}/bin/cmake \
        --ninja ${ninja}/bin/ninja \
        "$@"
    '';

    passthru = {inherit setupUnwrapped;};

    meta = {
      description = "WiiCompiled Linux setup CLI (translate + compile against your own PAL dump)";
      homepage = "https://github.com/patchzyy/Wiicompiled";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
      mainProgram = "wiicompiled-setup";
    };
  }
