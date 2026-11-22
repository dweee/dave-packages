# Hookshot Builder for Nix: the AppImage's contents (scripts/linux/appimage.sh) built from nixpkgs.
#
# No game data and nothing made from it is in this package. It carries the tools, the compiler and the prebuilt Vulkan
# back end; `hookshot-build` builds the game on this PC from the player's own copy into a folder in their home
# (~/Games/Hookshot), never into the Nix store, so it cannot reach a binary cache.
#
#   hookshot-build --nup <your-game.nup>      nx2/make_game.py; --out defaults to $HOOKSHOT_GAME_DIR or ~/Games/Hookshot
#   hookshot-build --update ~/Games/Hookshot  the folder built again with this package (after a flake bump)
#   hookshot [game arguments]                 start the game in $HOOKSHOT_GAME_DIR (or ~/Games/Hookshot)
#   hookshot-builder                          the Tk builder window (builder/linux/hookshot_builder.py)
{
  lib,
  stdenvNoCC,
  makeWrapper,
  patchelf,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  llvmPackages_23,
  pkg-config,
  ffmpeg-headless,
  sdl3,
  SDL2,
  vulkan-loader,
  vulkan-headers,
  spirv-headers,
  vulkan-memory-allocator,
  src,
  version,
  rev ? "unknown",
  # The renderer's and the game's CPU baseline. The AppImage uses x86-64-v3 (AVX2); the game's own build picks for
  # this CPU unless RX_MARCH is set.
  march ? "x86-64-v3",
}:
let
  inherit (llvmPackages_23) clang bintools;

  python = python3.withPackages (
    ps: with ps; [
      # requirements.txt: the tools (mandatory)
      lz4
      numpy
      capstone
      unicorn
      zstandard
      # nx2/prompt_requirements.txt: the button prompts (optional; astc-encoder-py and texture2ddecoder are not in
      # nixpkgs, so the game shows the Switch's icons)
      fonttools
      pillow
      archspec
      # builder/linux/hookshot_builder.py
      tkinter
    ]
  );

  # What the game and its renderer dlopen (host/posix/win32_posix.c LoadLibraryA: libSDL3.so.0, libSDL2-2.0.so.0,
  # libvulkan.so.1) and link (FFmpeg through pkg-config). make_game.py starts the game with LD_LIBRARY_PATH removed
  # (game_env), so these go into the game's RUNPATH at link time instead.
  runtimeLibs = [
    vulkan-loader
    sdl3
    SDL2
    ffmpeg-headless.lib
  ];
  runtimeLibPath = lib.makeLibraryPath runtimeLibs;

  # The ld wrapper's extra flags variable for this compiler (nixpkgs cc-wrapper's suffix salt).
  ldflagsVar = "NIX_LDFLAGS_${bintools.suffixSalt}";

  toolPath = lib.makeBinPath [
    bintools # wrapped ld.lld: clang -fuse-ld=lld finds it on PATH
    clang
    pkg-config
    python
  ];

  fullVersion = "v${version}-nix.${rev}";
in
stdenvNoCC.mkDerivation {
  pname = "hookshot-builder";
  version = "${version}-unstable-${rev}";
  inherit src;

  nativeBuildInputs = [
    bintools
    clang
    python
    pkg-config
    makeWrapper
    copyDesktopItems
    patchelf
  ];

  env = {
    HOOKSHOT_VULKAN_HEADERS = vulkan-headers;
    HOOKSHOT_SPIRV_HEADERS = spirv-headers;
    HOOKSHOT_VMA_HEADERS = vulkan-memory-allocator;
    HOOKSHOT_VERSION = fullVersion;
    PYTHONDONTWRITEBYTECODE = "1";
  };

  postPatch = ''
    patchShebangs builder/linux scripts
    # (nx2/version.py: no git history in the store)
    printf '%s\n' "${fullVersion}" > VERSION
  '';

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR

    # The Vulkan back end, built once here; it needs no game (scripts/linux/appimage.sh)
    OOT_WORK=$TMPDIR/vk-work RX_MARCH=${march} RX_VK_ONLY=1 RX_RELEASE=1 \
      python -I nx2/build.py --standalone --jobs $NIX_BUILD_CORES
    test -f $TMPDIR/vk-work/sa/build/hookshot_vk.so

    # The tools' native helpers: the store is read-only, so build them now with their stamps
    python -I third_party/a64-kit/lift/build_emit.py
    python -I -c "import sys; sys.path.insert(0, 'nx2'); import zbic; zbic.lib()"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    T=$out/share/hookshot
    mkdir -p $T $out/lib/hookshot $out/bin
    cp -a . $T/
    find $T -name __pycache__ -prune -exec rm -rf {} +
    install -Dm755 $TMPDIR/vk-work/sa/build/hookshot_vk.so $out/lib/hookshot/hookshot_vk.so
    # (the renderer has its own LoadLibraryA: its dlopen("libvulkan.so.1") searches its own RUNPATH, not the game's)
    patchelf --add-rpath ${runtimeLibPath} $out/lib/hookshot/hookshot_vk.so
    install -Dm644 assets/hookshot.png $out/share/icons/hicolor/256x256/apps/hookshot.png

    # nx2/make_game.py with the toolchain, the prebuilt renderer and the RUNPATH for the game
    buildEnv=(
      --prefix PATH : ${toolPath}
      --prefix PKG_CONFIG_PATH : ${lib.getDev ffmpeg-headless}/lib/pkgconfig
      --set ${ldflagsVar} "-rpath ${runtimeLibPath}"
      --set HOOKSHOT_VK_PREBUILT $out/lib/hookshot/hookshot_vk.so
      --set HOOKSHOT_VULKAN_HEADERS ${vulkan-headers}
      --set HOOKSHOT_SPIRV_HEADERS ${spirv-headers}
      --set HOOKSHOT_VMA_HEADERS ${vulkan-memory-allocator}
      --set PYTHONDONTWRITEBYTECODE 1
      --set-default HOOKSHOT_NO_UPDATE_CHECK 1
    )
    makeWrapper ${python}/bin/python3 $out/libexec/hookshot/make-game \
      "''${buildEnv[@]}" --add-flags "-I $T/nx2/make_game.py"
    # (the same Python and environment, for the other tools: scripts/oot_saves.py, nx2/dump.py ...)
    makeWrapper ${python}/bin/python3 $out/libexec/hookshot/python "''${buildEnv[@]}"
    makeWrapper ${python}/bin/python3 $out/bin/hookshot-builder \
      "''${buildEnv[@]}" --add-flags "-I $T/builder/linux/hookshot_builder.py"

    substitute ${./hookshot-build.sh} $out/bin/hookshot-build \
      --subst-var-by makeGame $out/libexec/hookshot/make-game
    substitute ${./hookshot.sh} $out/bin/hookshot \
      --subst-var-by runtimeLibPath ${runtimeLibPath}
    chmod +x $out/bin/hookshot-build $out/bin/hookshot
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "hookshot";
      desktopName = "Hookshot";
      comment = "Ocarina of Time (Switch 2), recompiled";
      exec = "hookshot";
      icon = "hookshot";
      categories = [ "Game" ];
    })
    (makeDesktopItem {
      name = "hookshot-builder";
      desktopName = "Hookshot Builder";
      comment = "Build Hookshot from your copy of the game";
      exec = "hookshot-builder";
      icon = "hookshot";
      categories = [ "Game" ];
    })
  ];

  # The renderer and helpers are already linked for this store; nothing to strip from the tools tree.
  dontStrip = true;
  # (patchelf --shrink-rpath would drop the dlopen-only entries above)
  dontPatchELF = true;

  passthru = {
    inherit python runtimeLibs;
    renderer = "lib/hookshot/hookshot_vk.so";
  };

  meta = {
    description = "Static recompilation of Ocarina of Time (Switch 2): the builder, built from your own copy";
    homepage = "https://git.notrexed.dev/Hookshot/Hookshot";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hookshot";
  };
}
