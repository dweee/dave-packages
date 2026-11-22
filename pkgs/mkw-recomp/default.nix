# mkw-recomp for Nix: the runtime with its start screen (build.py --dist --runtime-only, what a release ships) and
# setup/ with the tools the start screen's setup runs, all from nixpkgs instead of dist.py's downloads.
#
# Nothing of the game is in here, as in a release: the setup builds the game from the player's copy into their data
# folder (~/.local/share/mkw-recomp), never into the Nix store. bin/mkw-recomp does what the AppImage's AppRun does
# (tools/build/release.py APPRUN): it keeps a copy of mkw in that folder, whose folder the runtime uses for the game
# library, settings and caches, links setup/ there to the store, and starts it.
#
# setup/ as dist.py lays it out (tools/prepare/machine.py and runtime/ui/launcher/launcher_setup.cpp find it there):
#   python/  Python 3.14 with numpy and lz4        zig/  zig and its lib/ (the game code's C compiler)
#   glslc/   bin/glslc and lib/libshaderc_shared  src/  dist.SOURCES, the sources the setup runs
# NVIDIA's nvdisasm and ptxas (nvidia-tools.nix) go by MKW_NVIDIA_BIN (sm86/spec/spec.py), unfree and opt-in.
# By default spec.py obtains them at runtime, which on NixOS needs nix-ld.
#
# Build: nix build .#mkw-recomp      Run: nix run .#mkw-recomp
{
  lib,
  stdenv,
  llvmPackages,
  gcc,
  fetchurl,
  ninja,
  python314,
  sdl3,
  libopus,
  libvpx,
  zstd,
  xxhash,
  vulkan-headers,
  vulkan-loader,
  zig,
  shaderc,
  libarchive,
  dbus,
  coreutils,
  callPackage,
  makeDesktopItem,
  copyDesktopItems,
  src,
  version,
  withNvidiaTools ? false,
  nvidia-tools ? callPackage ./nvidia-tools.nix { },
}:
let
  # tools/build/README.md: the VMA 3.4.0 header, pinned there by sha256 (nixpkgs carries 3.5.0)
  vma = fetchurl {
    url = "https://raw.githubusercontent.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/v3.4.0/include/vk_mem_alloc.h";
    sha256 = "8487b7995ad3b263eb73bc5b9a77d71aa69b6bef5d58a715c02d2663afd81f1a";
  };

  # dist.py's portable CPython with numpy and lz4 (pyproject.toml: requires-python >= 3.14)
  python = python314.withPackages (ps: [
    ps.numpy
    ps.lz4
  ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "mkw-recomp";
  inherit version src;
  patches = [ ./runtime-environment.patch ];

  # stdenv is llvmPackages.stdenv (flake.nix): build.py calls clang and clang++ from PATH, Nix's wrapped ones with the
  # libraries' -I and -L.
  nativeBuildInputs = [
    llvmPackages.bintools # ld.lld, wrapped: the libraries' -rpath
    llvmPackages.llvm # llvm-ar
    ninja
    python
    copyDesktopItems
  ];
  buildInputs = [
    sdl3
    libopus
    libvpx
    zstd
    xxhash
    vulkan-headers
    vulkan-loader
  ];

  env = {
    MKW_CCACHE = "0";
    MKW_PORT_VERSION = finalAttrs.version;
    # The runtime is built with -O2 and its own -march (build.py RT_FLAGS); nixpkgs' fortify on top of -O2 is fine,
    # but its -fPIE default is not: build.py links with -no-pie (hundreds of thousands of function-table pointers).
    NIX_HARDENING_ENABLE = "";
    # -l:libstdc++.a: the runtime links libstdc++ statically, as the release does; the archive is in gcc's out
    NIX_LDFLAGS = "-L${gcc.cc}/lib";
  };

  postPatch = ''
    patchShebangs tools
    mkdir -p scratchpad/vma
    cp ${vma} scratchpad/vma/vk_mem_alloc.h
  '';

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    python3 tools/build/build.py --dist --runtime-only --jobs $NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    share=$out/share/mkw-recomp
    install -Dm755 build/dist/linux/mkw $share/mkw
    install -Dm644 build/dist/linux/mkwgame.id $share/mkwgame.id

    setup=$share/setup
    mkdir -p $setup/src
    # dist.py's own list: tests/test_setup.py checks every tool the launcher names is in it
    python3 -I -c 'import sys; sys.path.insert(0, "tools/build"); import dist; print("\n".join(dist.SOURCES))' \
      | while read -r rel; do
        mkdir -p "$setup/src/$(dirname "$rel")"
        cp -r "$rel" "$setup/src/$rel"
      done
    find $setup/src \( -name __pycache__ -o -name README.md \) -prune -exec rm -rf {} +

    ln -s ${python} $setup/python
    mkdir -p $setup/zig $setup/glslc/bin $setup/glslc/lib
    ln -s ${lib.getExe zig} $setup/zig/zig
    ln -s ${zig}/lib/zig $setup/zig/lib
    ln -s ${lib.getBin shaderc}/bin/glslc $setup/glslc/bin/glslc
    ln -s ${lib.getLib shaderc}/lib/libshaderc_shared.so.1 $setup/glslc/lib/libshaderc_shared.so.1

    install -Dm644 LICENSE $out/share/licenses/mkw-recomp/LICENSE
    mkdir -p $out/share/icons/hicolor/256x256/apps
    python3 tools/build/icon.py $out/share/icons/hicolor/256x256/apps/mkw-recomp.png

    mkdir -p $out/bin
    substitute ${./mkw-recomp.sh} $out/bin/mkw-recomp \
      --subst-var-by share $share \
      --subst-var-by path ${
        lib.makeBinPath [
          coreutils
          libarchive
        ]
      } \
      --subst-var-by libs ${lib.makeLibraryPath [ dbus ]} \
      --subst-var-by nvidia ${lib.escapeShellArg (lib.optionalString withNvidiaTools "${nvidia-tools}/bin")}
    chmod +x $out/bin/mkw-recomp
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "mkw-recomp";
      desktopName = "mkw-recomp";
      comment = "Static recompilation of Mario Kart World; builds the game from your own copy";
      exec = "mkw-recomp";
      icon = "mkw-recomp";
      categories = [ "Game" ];
    })
  ];

  passthru = { inherit nvidia-tools python vma; };

  meta = {
    description = "Static recompilation of Mario Kart World (Switch 2) to native code; needs your own dump";
    homepage = "https://github.com/adriadam10/mkw-recomp";
    license = lib.licenses.mit;
    mainProgram = "mkw-recomp";
    # build.py's ARCH_FLAGS: x86-64-v3 or ARMv8.2; the runtime has no macOS platform layer yet
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
