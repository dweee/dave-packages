{
  lib,
  packageVersion ? "0.9.4",
  stdenv,
  cmake,
  ninja,
  python3,
  ccache,
  apple-sdk_15,
  writeShellScript,
  src,
  translateSrc,
  patches ? [ ],
  iso ? null,
  # Named clang -mcpu (e.g. apple-m4). Null uses CMake's apple-m1 floor.
  hostCpu ? null,
  # Wheel Wizard RetroRewind6 tree. Native RetroRewind.app when set; Riivolution
  # tracks still need the darwin module's Application Support copy.
  retroRewind ? null,
  wiicompiled-translator,
  discExtractor ? null,
  retroWfcPayload ? null,
  wiicompiled-native-prebuilt,
  callPackage,
}:
let
  intel = stdenv.hostPlatform.isx86_64;
  commonMeta = {
    description = "Mario Kart Wii translated to native code (user-supplied PAL dump)";
    homepage = "https://github.com/patchzyy/Wiicompiled";
    license = lib.licenses.unfree;
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "wiicompiled";
  };
  publishPath = "${
    lib.makeBinPath [
      cmake
      ninja
      python3
      ccache
    ]
  }:/usr/bin:/usr/sbin:/bin";
in
if iso == null || intel then
  stdenv.mkDerivation {
    pname = "wiicompiled";
    version = packageVersion;
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      if [ ${lib.boolToString intel} = true ]; then
        echo "wiicompiled: Intel Macs are not a supported product target." >&2
        echo "Upstream CMake and local-build-macos.command are Apple Silicon only." >&2
      else
        echo "wiicompiled: override iso with requireFile of your PAL RMCP01 dump and set discExtractor." >&2
          fi
      exit 1
    '';
    meta = commonMeta // {
      broken = true;
    };
  }
else
  let
    disc = callPackage ./disc.nix { inherit iso discExtractor; };
    translated = callPackage ./translate.nix {
      src = translateSrc;
      inherit
        packageVersion
        disc
        retroRewind
        wiicompiled-translator
        retroWfcPayload
        ;
    };
    # Finder .app has no wrapper, so the darwin module still copies the pack
    # into Application Support. The bin wrappers do the same at launch so a
    # flake `nix build` result works without that activation.
    buildProgress = callPackage ./build-progress.nix { };
    wrapper = writeShellScript "wiicompiled-macos-wrapper" ''
      set -euo pipefail
      dvd=@dvd@
      exe=@exe@
      rr=@rr@
      support="$HOME/Library/Application Support/WiiCompiled"
      cfg="$support/Config.toml"
      sd="$support/Riivolution"
      mkdir -p "$(dirname "$cfg")" "$sd/riivolution/save" "$sd/RetroRewind6"
      toml_string() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
      set_path() {
        local key=$1 value=$2 encoded line temporary
        encoded=$(toml_string "$value"); line="$key = \"$encoded\""; temporary="$cfg.tmp"
        touch "$cfg"
        if grep -q '^[[:space:]]*\[paths\][[:space:]]*$' "$cfg"; then
          awk -v key="$key" -v line="$line" '
            /^[[:space:]]*\[paths\][[:space:]]*$/ { print; print line; inside = 1; next }
            inside && /^[[:space:]]*\[/ { inside = 0 }
            inside && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { next }
            { print }
          ' "$cfg" > "$temporary"
        else
          { cat "$cfg"; printf '\n[paths]\n%s\n' "$line"; } > "$temporary"
        fi
        mv "$temporary" "$cfg"
      }
      set_path dvd_root "$dvd"
      if [ -n "$rr" ]; then
        for n in "$rr"/*; do
          [ -e "$n" ] || continue
          ln -sfn "$n" "$sd/RetroRewind6/$(basename "$n")"
        done
        set_path retro_rewind_root "$sd/RetroRewind6"
      fi
      exec "$exe" "$@"
    '';
  in
  stdenv.mkDerivation {
    pname = "wiicompiled";
    version = packageVersion;
    inherit src iso patches;

    dontUseCmakeConfigure = true;

    nativeBuildInputs = [
      cmake
      ninja
      python3
      ccache
    ];

    # Prebuilt Dawn (QueueMTL.mm) references MTLLogStateDescriptor, which is not
    # in the default apple-sdk 14.4 Metal.tbd.
    buildInputs = [
      apple-sdk_15
      wiicompiled-native-prebuilt
    ];

    preferLocalBuild = true;
    allowSubstitutes = false;
    # publish-app.command ad-hoc signs the .app; stdenv strip would invalidate it.
    dontStrip = true;

    postPatch = ''
      patchShebangs Launcher/macos/publish-app.command
    '';

    buildPhase = ''
      runHook preBuild
      ln -s ${translated}/generated generated
      ${lib.optionalString (retroRewind != null) ''
        mkdir -p build
        ln -sfn ${translated}/build/mods build/mods
      ''}

      mkdir -p prebuilt
      for sibling in ${wiicompiled-native-prebuilt}/*; do
        ln -s "$sibling" "prebuilt/$(basename "$sibling")"
      done
      rm -f prebuilt/native_prebuilt
      cp -a ${wiicompiled-native-prebuilt}/native_prebuilt prebuilt/native_prebuilt
      chmod -R u+w prebuilt/native_prebuilt
      python3 ${./coalesce-macos-link-flags.py} prebuilt/native_prebuilt/native_prebuilt.cmake
      cat ${./tame-huge-translated.cmake} >> runtime/cmake/PublicProducts.cmake

      # Aurora adds MetalFX with target_link_options, which Ninja records in
      # LINK_FLAGS. The native-prebuilt harvest keeps only LINK_LIBRARIES, so
      # pass the weak framework here or metalfx.mm.o fails to link.

      # stdenv clang with an absolute path. Do not set SDKROOT: apple-sdk's
      # xcrun is xcbuild and will ignore CMAKE_CXX_COMPILER and pick a random
      # clang++ off PATH.
      unset SDKROOT
      unset DEVELOPER_DIR
      ${buildProgress.launchersHook { inherit ccache; }}
      echo "wiicompiled cxx: ${stdenv.cc}/bin/clang++" >&2
      ${stdenv.cc}/bin/clang++ --version | head -1 >&2

      cmake -S runtime -B native-build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=${stdenv.cc}/bin/clang \
        -DCMAKE_CXX_COMPILER=${stdenv.cc}/bin/clang++ \
        -DCMAKE_ASM_COMPILER=${stdenv.cc}/bin/clang \
        -DCMAKE_OSX_SYSROOT=${apple-sdk_15.sdkroot} \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-weak_framework,MetalFX" \
        -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja \
        -DMKW_NATIVE_PREBUILT_DIR="$PWD/prebuilt/native_prebuilt" \
        -DCMAKE_C_COMPILER_LAUNCHER="$compile_launchers" \
        -DCMAKE_CXX_COMPILER_LAUNCHER="$compile_launchers" \
        -DCMAKE_ASM_COMPILER_LAUNCHER="$compile_launchers" \
        -DCMAKE_C_LINKER_LAUNCHER=${buildProgress.announceCompile} \
        -DCMAKE_CXX_LINKER_LAUNCHER=${buildProgress.announceCompile} \
        -DMKW_TRANSLATED_COMPILE_JOBS="''${NIX_BUILD_CORES:-1}" \
        ${
          lib.optionalString (
            hostCpu != null && hostCpu != ""
          ) "-DMKW_BASELINE_ARCH=${lib.escapeShellArg hostCpu}"
        } \
        -Wno-dev

      ${buildProgress.cmakeBuild} native-build --target WiiCompiled \
        ${lib.optionalString (retroRewind != null) "--target RetroRewind"} \
        --parallel "''${NIX_BUILD_CORES:-1}"

      env PATH=${publishPath}''${PATH:+:$PATH} \
        bash Launcher/macos/publish-app.command \
          --build-dir "$PWD/native-build" \
          --product WiiCompiled \
          --output-dir "$PWD/publish"
      ${lib.optionalString (retroRewind != null) ''
        env PATH=${publishPath}''${PATH:+:$PATH} \
          bash Launcher/macos/publish-app.command \
            --build-dir "$PWD/native-build" \
            --product RetroRewind \
            --output-dir "$PWD/publish"
      ''}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications $out/share/wiicompiled $out/bin
      cp -a publish/WiiCompiled.app $out/Applications/
      cp -a ${disc}/DATA $out/share/wiicompiled/DATA
      substitute ${wrapper} $out/bin/wiicompiled \
        --subst-var-by dvd $out/share/wiicompiled/DATA \
        --subst-var-by exe $out/Applications/WiiCompiled.app/Contents/MacOS/WiiCompiled \
        --subst-var-by rr ""
      chmod +x $out/bin/wiicompiled
      ${lib.optionalString (retroRewind != null) ''
        cp -a publish/RetroRewind.app $out/Applications/
        substitute ${wrapper} $out/bin/wiicompiled-retro \
          --subst-var-by dvd $out/share/wiicompiled/DATA \
          --subst-var-by exe $out/Applications/RetroRewind.app/Contents/MacOS/RetroRewind \
          --subst-var-by rr ${retroRewind}
        chmod +x $out/bin/wiicompiled-retro
      ''}
      runHook postInstall
    '';

    passthru = {
      inherit disc translated;
      nativePrebuilt = wiicompiled-native-prebuilt;
    };

    meta = commonMeta;
  }
