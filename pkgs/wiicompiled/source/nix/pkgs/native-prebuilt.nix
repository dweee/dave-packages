{
  lib,
  stdenv,
  cmake,
  ninja,
  clang,
  lld,
  pkg-config,
  python3,
  apple-sdk_15 ? null,
  vulkan-headers,
  vulkan-loader,
  wayland,
  wayland-protocols,
  libxkbcommon,
  libffi,
  libGL,
  libglvnd,
  libdrm,
  libusb1,
  dbus,
  udev,
  alsa-lib,
  pulseaudio,
  pipewire,
  openssl,
  zlib,
  libx11,
  libxext,
  libxcursor,
  libxfixes,
  libxi,
  libxrandr,
  libxcb,
  libdecor,
  ibus,
  xorg,
  src,
  callPackage,
}: let
  deps = callPackage ./deps.nix {};
  darwin = stdenv.hostPlatform.isDarwin;
  intelDarwin = darwin && stdenv.hostPlatform.isx86_64;
  linuxLibs = [
    vulkan-headers
    vulkan-loader
    wayland
    wayland-protocols
    libxkbcommon
    libffi
    libGL
    libglvnd
    libdrm
    libusb1
    dbus
    udev
    alsa-lib
    pulseaudio
    pipewire
    openssl
    zlib
    libx11
    libxext
    libxcursor
    libxfixes
    libxi
    libxrandr
    libdecor
    ibus
    xorg.libX11
    xorg.libXext
    xorg.libXcursor
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXScrnSaver
    xorg.libXtst
    libxcb
  ];
  depStage = {
    sdl = deps.sdl;
    imgui = deps.imgui;
    tracy = deps.tracy;
    abseil = deps.abseil;
    fmt = deps.fmt;
    xxhash = deps.xxhash;
    zlib = deps.zlib;
    libpng = deps.libpng;
    freetype = deps.freetype;
    zstd = deps.zstd;
    sqlite3 = deps.sqlite3;
    dawn_prebuilt = deps.dawnPrebuilt;
  };
  cmakeSourceFlags = [
    "-DFETCHCONTENT_SOURCE_DIR_SDL=$PWD/deps/sdl"
    "-DFETCHCONTENT_SOURCE_DIR_IMGUI=$PWD/deps/imgui"
    "-DFETCHCONTENT_SOURCE_DIR_TRACY=$PWD/deps/tracy"
    "-DFETCHCONTENT_SOURCE_DIR_ABSEIL-CPP=$PWD/deps/abseil"
    "-DFETCHCONTENT_SOURCE_DIR_FMT=$PWD/deps/fmt"
    "-DFETCHCONTENT_SOURCE_DIR_XXHASH=$PWD/deps/xxhash"
    "-DFETCHCONTENT_SOURCE_DIR_ZLIB=$PWD/deps/zlib"
    "-DFETCHCONTENT_SOURCE_DIR_PNG=$PWD/deps/libpng"
    "-DFETCHCONTENT_SOURCE_DIR_FREETYPE=$PWD/deps/freetype"
    "-DFETCHCONTENT_SOURCE_DIR_ZSTD=$PWD/deps/zstd"
    "-DFETCHCONTENT_SOURCE_DIR_SQLITE3=$PWD/deps/sqlite3"
    "-DFETCHCONTENT_SOURCE_DIR_DAWN_PREBUILT=$PWD/deps/dawn_prebuilt"
  ];
in
  if intelDarwin
  then
    stdenv.mkDerivation {
      pname = "wiicompiled-native-prebuilt";
      version = "0.2.32";
      dontUnpack = true;
      dontBuild = true;
      installPhase = ''
        echo "wiicompiled-native-prebuilt: Intel Macs are not a supported product target." >&2
        exit 1
      '';
      meta = {
        description = "Precompiled aurora + third-party archives for WiiCompiled";
        homepage = "https://github.com/patchzyy/Wiicompiled";
        license = lib.licenses.gpl3Only;
        platforms = ["aarch64-darwin" "x86_64-darwin"];
        broken = true;
      };
    }
  else
    stdenv.mkDerivation {
      pname = "wiicompiled-native-prebuilt";
      version = "0.2.32";
      inherit src;

      dontUseCmakeConfigure = true;
      dontStrip = true;
      # Archives + CMake description only. Darwin buildPhase puts /usr/bin on
      # PATH for Apple clang; BSD stat then breaks stdenv fixup (`stat --`).
      dontFixup = true;
      allowSubstitutes = true;

      nativeBuildInputs =
        [
          cmake
          ninja
          python3
        ]
        ++ lib.optionals (!darwin) [clang lld pkg-config];

      buildInputs = lib.optionals darwin [apple-sdk_15] ++ lib.optionals (!darwin) linuxLibs;

      buildPhase = ''
        runHook preBuild
        mkdir -p deps export build package/native_prebuilt
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: drv: ''
            cp -a ${drv} deps/${name}
            chmod -R u+w deps/${name}
          '')
          depStage)}

        ${lib.optionalString darwin ''
          export SDKROOT=${apple-sdk_15.sdkroot}
          export PATH=${lib.makeBinPath [cmake ninja python3]}:/usr/bin:/usr/sbin:/bin''${PATH:+:$PATH}
        ''}
        ${lib.optionalString (!darwin) ''
          export PATH=${lib.makeBinPath [cmake ninja python3 clang lld pkg-config]}''${PATH:+:$PATH}
        ''}

        cmake -S runtime -B build -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          ${
          if darwin
          then ''-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++''
          else ''-DCMAKE_C_COMPILER=${clang}/bin/clang -DCMAKE_CXX_COMPILER=${clang}/bin/clang++''
        } \
          -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja \
          ${lib.optionalString (!darwin) ''-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=${lld}/bin/ld.lld"''} \
          -DMKW_NATIVE_PREBUILT_EXPORT_DIR="$PWD/export" \
          -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
          -DCMAKE_POLICY_DEFAULT_CMP0168=NEW \
          -DBUILD_SHARED_LIBS=OFF \
          -DAURORA_DAWN_PROVIDER=package \
          -DAURORA_SDL3_PROVIDER=vendor \
          -DMKW_ENABLE_OPENXR=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_absl=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_PNG=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Freetype=ON \
          -DFT_DISABLE_BZIP2=ON \
          ${lib.concatStringsSep " \\\n          " cmakeSourceFlags} \
          -Wno-dev

        cmake --build build --target mkw_np_probe --parallel "''${NIX_BUILD_CORES:-1}"

        python3 ${./harvest-native-prebuilt.py} \
          --export-dir "$PWD/export" \
          --build-dir "$PWD/build" \
          --aurora-dir "$PWD/aurora-main" \
          --runtime-dir "$PWD/runtime" \
          --deps-dir "$PWD/deps" \
          --package-dir "$PWD/package/native_prebuilt"

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -a package/native_prebuilt $out/native_prebuilt
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
            cp -a deps/${name} $out/${name}
          '')
          depStage)}
        test -f $out/native_prebuilt/native_prebuilt.cmake
        test -f $out/native_prebuilt/lib/libmkw_cryptopp.a
        runHook postInstall
      '';

      meta = {
        description = "Precompiled aurora + third-party archives for WiiCompiled";
        homepage = "https://github.com/patchzyy/Wiicompiled";
        license = lib.licenses.gpl3Only;
        platforms = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
      };
    }
