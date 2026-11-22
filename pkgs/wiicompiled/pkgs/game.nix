{
  lib,
  packageVersion ? "0.9.4",
  stdenv,
  cmake,
  ninja,
  clang,
  lld,
  pkg-config,
  makeDesktopItem,
  copyDesktopItems,
  writeShellScript,
  ccache,
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
  translateSrc,
  patches ? [ ],
  iso ? null,
  # Named -march (x86_64) or -mcpu (aarch64). Null uses CMake's portable floor.
  hostCpu ? null,
  # Wheel Wizard RetroRewind6 tree (or any canonical RetroRewind6). Not a fork of
  # Retro Rewind itself; the existing WiiCompiled translator already has the profile.
  retroRewind ? null,
  wiicompiled-translator,
  discExtractor ? null,
  retroWfcPayload ? null,
  wiicompiled-native-prebuilt,
  callPackage,
}:
if iso == null then
  stdenv.mkDerivation {
    pname = "wiicompiled";
    version = packageVersion;
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      echo "wiicompiled: override iso with requireFile of your PAL RMCP01 dump and set discExtractor." >&2
      exit 1
    '';
    meta = {
      description = "WiiCompiled translated game (requires your PAL dump via iso=)";
      homepage = "https://github.com/patchzyy/Wiicompiled";
      license = lib.licenses.unfree;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
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

    buildProgress = callPackage ./build-progress.nix { };
    wrapper = writeShellScript "wiicompiled-wrapper" ''
      set -euo pipefail
      dvd=@dvd@
      exe=@exe@
      rr=@rr@
      cfg="''${XDG_DATA_HOME:-$HOME/.local/share}/WiiCompiled/Config.toml"
      mkdir -p "$(dirname "$cfg")"
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
        set_path retro_rewind_root "$rr"
      fi
      export LD_LIBRARY_PATH=${
        lib.makeLibraryPath [
          vulkan-loader
          wayland
          libxkbcommon
          libGL
          libglvnd
          libusb1
          dbus
          udev
          alsa-lib
          pulseaudio
          pipewire
          libx11
          libxext
          libxcursor
          libxfixes
          libxi
          libxrandr
          libdecor
          xorg.libXtst
          libxcb
        ]
      }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec "$exe" "$@"
    '';
    # XML paths are /RetroRewind6/... and /riivolution/save/... relative to the
    # overlay parent. Pointing retro_rewind_root at a store pack makes the parent
    # /nix/store (Pulsar Config missing, save under /nix/store/riivolution/...).
    linuxLauncher = writeShellScript "wiicompiled-linux-launcher" ''
          set -euo pipefail
          dvd=@dvd@
          exe=@exe@
          rr=@rr@
          support="''${XDG_DATA_HOME:-$HOME/.local/share}/WiiCompiled"
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
              base=$(basename "$n")
              # Pack XML maps Patches/; My Stuff maps MyStuff/. Both must stay
              # writable — a store symlink is empty and read-only.
              case "$base" in
                MyStuff|Patches) continue ;;
              esac
              ln -sfn "$n" "$sd/RetroRewind6/$base"
            done
            for overlay_dir in MyStuff Patches; do
              dest="$sd/RetroRewind6/$overlay_dir"
              if [ -L "$dest" ]; then
                rm -f "$dest"
              fi
              mkdir -p "$dest"
            done
            # My Stuff defaults to off (choice 0). Pin RR (choice 2) unless the user
            # already has Dolphin-style remembered choices.
            cfgxml="$sd/riivolution/config/RMCP.xml"
            if [ ! -e "$cfgxml" ]; then
              mkdir -p "$(dirname "$cfgxml")"
              cat > "$cfgxml" << 'EOF'
      <riivolution version="2">
        <option id="Retro RewindMy Stuff" default="2" />
      </riivolution>
      EOF
            fi
            set_path retro_rewind_root "$sd/RetroRewind6"
          fi
          export LD_LIBRARY_PATH=${
            lib.makeLibraryPath [
              vulkan-loader
              wayland
              libxkbcommon
              libGL
              libglvnd
              libusb1
              dbus
              udev
              alsa-lib
              pulseaudio
              pipewire
              libx11
              libxext
              libxcursor
              libxfixes
              libxi
              libxrandr
              libdecor
              xorg.libXtst
              libxcb
              zlib
              stdenv.cc.cc.lib
            ]
          }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
          exec "$exe" "$@"
    '';
  in
  let
    unwrapped = stdenv.mkDerivation {
      pname = "wiicompiled";
      version = packageVersion;
      inherit src patches;

      dontUseCmakeConfigure = true;

      nativeBuildInputs = [
        cmake
        ninja
        clang
        lld
        pkg-config
        copyDesktopItems
        ccache
      ];

      buildInputs = [
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
        wiicompiled-native-prebuilt
      ];

      desktopItems = [
        (makeDesktopItem {
          name = "wiicompiled";
          desktopName = "WiiCompiled";
          exec = "wiicompiled";
          comment = "Mario Kart Wii (native recompilation)";
          categories = [ "Game" ];
        })
      ]
      ++ lib.optionals (retroRewind != null) [
        (makeDesktopItem {
          name = "wiicompiled-retro";
          desktopName = "WiiCompiled Retro Rewind";
          exec = "wiicompiled-retro";
          comment = "Mario Kart Wii Retro Rewind (native recompilation)";
          categories = [ "Game" ];
        })
      ];

      inherit iso;

      # The executable and disc files are derived from the local dump.
      preferLocalBuild = true;
      allowSubstitutes = false;

      buildPhase = ''
        runHook preBuild
        ln -s ${translated}/generated generated
        ${lib.optionalString (retroRewind != null) ''
          mkdir -p build
          ln -sfn ${translated}/build/mods build/mods
        ''}

        cat ${./tame-huge-translated.cmake} >> runtime/cmake/PublicProducts.cmake
        ${buildProgress.launchersHook { inherit ccache; }}
        cmake -S runtime -B native-build -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_C_COMPILER=${clang}/bin/clang \
          -DCMAKE_CXX_COMPILER=${clang}/bin/clang++ \
          -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja \
          -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=${lld}/bin/ld.lld" \
          -DMKW_NATIVE_PREBUILT_DIR=${wiicompiled-native-prebuilt}/native_prebuilt \
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
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/libexec/wiicompiled $out/share/wiicompiled $out/bin
        cp -a native-build/WiiCompiled $out/libexec/wiicompiled/
        for name in dsp_coef.bin initial_pipeline_cache.db; do
          [ -f native-build/$name ] && cp -a native-build/$name $out/libexec/wiicompiled/
        done${lib.optionalString (lib.versionAtLeast packageVersion "0.9.4") "\n      install -m444 native-build/cacert.pem $out/libexec/wiicompiled/cacert.pem"}
        [ -d native-build/wii_bootstrap ] && cp -a native-build/wii_bootstrap $out/libexec/wiicompiled/
        cp -a ${disc}/DATA $out/share/wiicompiled/DATA

        substitute ${wrapper} $out/bin/wiicompiled \
          --subst-var-by dvd $out/share/wiicompiled/DATA \
          --subst-var-by exe $out/libexec/wiicompiled/WiiCompiled \
          --subst-var-by rr ""
        chmod +x $out/bin/wiicompiled
        ${lib.optionalString (retroRewind != null) ''
          cp -a native-build/RetroRewind $out/libexec/wiicompiled/
          substitute ${wrapper} $out/bin/wiicompiled-retro \
            --subst-var-by dvd $out/share/wiicompiled/DATA \
            --subst-var-by exe $out/libexec/wiicompiled/RetroRewind \
            --subst-var-by rr ${retroRewind}
          chmod +x $out/bin/wiicompiled-retro
        ''}
        find "$out/libexec" -type f -executable -print0 | xargs -0 -r patchelf --remove-rpath
        runHook postInstall
      '';

      passthru = {
        inherit disc translated;
        nativePrebuilt = wiicompiled-native-prebuilt;
      };

      meta = {
        description = "Mario Kart Wii translated to native code (user-supplied PAL dump)";
        homepage = "https://github.com/patchzyy/Wiicompiled";
        license = lib.licenses.unfree;
        platforms = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        mainProgram = "wiicompiled";
      };
    };
  in
  # Cheap launcher: keep the compiled game drv. XML /RetroRewind6/... is
  # relative to the overlay parent, so the store pack cannot be the root.
  stdenv.mkDerivation {
    pname = "wiicompiled";
    inherit (unwrapped) version meta;
    preferLocalBuild = true;
    allowSubstitutes = false;
    dontUnpack = true;
    dontBuild = true;
    passthru = unwrapped.passthru // {
      inherit unwrapped;
    };
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      ln -s ${unwrapped}/libexec $out/libexec
      ln -s ${unwrapped}/share $out/share
      substitute ${linuxLauncher} $out/bin/wiicompiled \
        --subst-var-by dvd ${unwrapped}/share/wiicompiled/DATA \
        --subst-var-by exe ${unwrapped}/libexec/wiicompiled/WiiCompiled \
        --subst-var-by rr ""
      chmod +x $out/bin/wiicompiled
      ${lib.optionalString (retroRewind != null) ''
        substitute ${linuxLauncher} $out/bin/wiicompiled-retro \
          --subst-var-by dvd ${unwrapped}/share/wiicompiled/DATA \
          --subst-var-by exe ${unwrapped}/libexec/wiicompiled/RetroRewind \
          --subst-var-by rr ${retroRewind}
        chmod +x $out/bin/wiicompiled-retro
      ''}
      runHook postInstall
    '';
  }
