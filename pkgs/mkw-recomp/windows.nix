{
  lib,
  stdenvNoCC,
  fetchurl,
  callPackage,
  cmake,
  ninja,
  python314,
  p7zip,
  file,
  src,
  version,
}:
let
  buildPins = lib.importJSON ./windows-build-inputs.json;
  setupPins = lib.importJSON ./windows-setup-inputs.json;
  clangVersion = setupPins.llvm-clang.version;
  llvm-mingw = callPackage ../llvm-mingw.nix {
    version = "20261020";
    hash = buildPins.llvm-mingw.sha256;
  };
  # Preseed the upstream scripts' download directories. They verify the bytes
  # again and assemble the SDL cross build and the setup tools offline.
  stage =
    directory: pins:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        key: pin:
        let
          basename = lib.replaceStrings [ "%2B" "%7E" ] [ "+" "~" ] (baseNameOf pin.url);
          archive =
            if key == "llvm-mingw" then
              llvm-mingw.archive
            else
              fetchurl {
                inherit (pin) url sha256;
                name = basename;
              };
        in
        "ln -s ${archive} ${directory}/${lib.escapeShellArg basename}"
      ) pins
    );
in
stdenvNoCC.mkDerivation {
  pname = "mkw-recomp-windows";
  inherit src version;
  patches = [ ./runtime-environment.patch ];

  nativeBuildInputs = [
    cmake
    ninja
    python314
    p7zip
    file
  ];
  dontConfigure = true;
  dontFixup = true;
  env = {
    MKW_CCACHE = "0";
    MKW_PORT_VERSION = version;
  };

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    export CMAKE_BUILD_PARALLEL_LEVEL=$NIX_BUILD_CORES
    mkdir -p build/win/dl build/dist/dl
    ${stage "build/win/dl" buildPins}
    ${stage "build/dist/dl" setupPins}
    # llvm_clang.py uses an extracted-binary cache before fetching its installer.
    clangCache=build/dist/dl/llvm-${clangVersion}-windows
    mkdir -p "$clangCache"
    7z e -y "-o$clangCache" build/dist/dl/LLVM-${clangVersion}-win64.exe bin/clang.exe >/dev/null
    test -s "$clangCache/clang.exe"
    ln -s ${llvm-mingw} build/win/llvm-mingw
    python3 -I tools/build/windeps.py
    python3 -I tools/build/build.py --target windows --dist --runtime-only --jobs "$NIX_BUILD_CORES"
    # Keep Python's environment and user site isolated while allowing the
    # pinned dist.py to import its sibling llvm_clang.py.
    python3 -Es tools/build/dist.py --target windows
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    dist=build/dist/windows
    file "$dist/mkw.exe" | grep -E 'PE32\+.*x86-64'
    test -s "$dist/setup/lib/crt/link.json"
    test -s "$dist/setup/clang/clang.exe"
    test -f "$dist/setup/src/tools/prepare/prepare.py"
    mkdir -p "$out" "$out/share/licenses/mkw-recomp"
    cp -a "$dist/." "$out/"
    cp -a build/win/deps/share/licenses "$out/share/licenses/windows-deps"
    install -Dm644 LICENSE "$out/share/licenses/mkw-recomp/LICENSE"
    runHook postInstall
  '';

  meta.description = "Mario Kart World Windows start screen and setup tools cross-compiled from Linux";
  meta.platforms = [ "x86_64-linux" ];
}
