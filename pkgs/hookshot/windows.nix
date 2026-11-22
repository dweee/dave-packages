{
  stdenvNoCC,
  fetchurl,
  callPackage,
  python3,
  meson,
  ninja,
  nasm,
  pkg-config,
  file,
  vulkan-headers,
  spirv-headers,
  vulkan-memory-allocator,
  src,
  version,
  rev,
}:
let
  llvm-mingw = callPackage ../llvm-mingw.nix {
    version = "20261104";
    hash = "919380403de87dca3c581c2053230cd298af5e891286628ba0613b7fed370926";
  };
  dav1d = fetchurl {
    url = "https://code.videolan.org/videolan/dav1d/-/archive/1.5.4/dav1d-1.5.4.tar.gz";
    hash = "sha256-odW2PS047JvQOs9kPKpR+iLt0eicWhCcSAdxcha77Ac=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "hookshot-windows";
  version = "${version}-unstable-${rev}";
  inherit src;

  nativeBuildInputs = [
    python3
    meson
    ninja
    nasm
    pkg-config
    file
  ];
  dontConfigure = true;
  dontFixup = true;

  env = {
    HOOKSHOT_MINGW = llvm-mingw;
    HOOKSHOT_VERSION = "v${version}-nix.${rev}";
    HOOKSHOT_VULKAN_HEADERS = vulkan-headers;
    HOOKSHOT_SPIRV_HEADERS = spirv-headers;
    HOOKSHOT_VMA_HEADERS = vulkan-memory-allocator;
    RX_TARGET = "windows";
    RX_VK_ONLY = "1";
    RX_RELEASE = "1";
  };

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    mingw=$HOOKSHOT_MINGW/bin
    target=$mingw/x86_64-w64-mingw32

    # The same cross compiler and static AV1 decoder as the upstream builder.
    mkdir "$TMPDIR/dav1d"
    tar -xf ${dav1d} -C "$TMPDIR/dav1d" --strip-components=1
    cat > "$TMPDIR/dav1d-cross.ini" <<CROSS
    [binaries]
    c = '$target-clang'
    ar = '$mingw/llvm-ar'
    strip = '$mingw/llvm-strip'
    windres = '$target-windres'
    nasm = 'nasm'

    [built-in options]
    c_args = ['-mno-incremental-linker-compatible']

    [host_machine]
    system = 'windows'
    cpu_family = 'x86_64'
    cpu = 'x86_64'
    endian = 'little'
    CROSS
    meson setup "$TMPDIR/dav1d-build" "$TMPDIR/dav1d" --cross-file "$TMPDIR/dav1d-cross.ini" \
      --prefix="$TMPDIR/cpm/dav1d/1.5.4" --libdir=lib --buildtype=release --default-library=static \
      -Denable_tools=false -Denable_tests=false -Denable_examples=false -Db_ndebug=true
    ninja -C "$TMPDIR/dav1d-build" -j "$NIX_BUILD_CORES" install

    OOT_WORK=$TMPDIR/vk-work RX_CPM=$TMPDIR/cpm python3 -I nx2/build.py --standalone --jobs "$NIX_BUILD_CORES"
    (
      cd builder/setup
      "$target-windres" setup.rc -O coff -o "$TMPDIR/setup_rc.o"
      "$target-clang" -O2 -mwindows -municode setup.c "$TMPDIR/setup_rc.o" \
        -lwinhttp -lbcrypt -lcomctl32 -lshell32 -lole32 -Wl,--dependent-load-flag=0x800 \
        -o "$TMPDIR/HookshotBuilder-Setup.exe"
    )
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    renderer="$TMPDIR/vk-work/sa/build/hookshot_vk.dll"
    file "$renderer" "$TMPDIR/HookshotBuilder-Setup.exe" | tee "$TMPDIR/pe-files"
    test "$(grep -c 'PE32+.*x86-64' "$TMPDIR/pe-files")" -eq 2
    install -Dm755 "$renderer" "$out/bin/hookshot_vk.dll"
    install -Dm755 "$TMPDIR/HookshotBuilder-Setup.exe" "$out/bin/HookshotBuilder-Setup.exe"
    mkdir -p "$out/share/hookshot/cpm/dav1d"
    cp -a "$TMPDIR/cpm/dav1d/1.5.4" "$out/share/hookshot/cpm/dav1d/"
    install -Dm644 "$TMPDIR/dav1d/COPYING" "$out/share/licenses/dav1d/COPYING"
    runHook postInstall
  '';

  meta.description = "Windows Vulkan renderer, AV1 decoder and bootstrap installer for Hookshot";
  meta.platforms = [ "x86_64-linux" ];
}
