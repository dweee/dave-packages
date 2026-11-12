# YAAS (skrimix/yaas). Expression adapted from
# hilorioze/nixos-dotfiles packages/yaas @ c2acca0990910ca01905c71ce00f9a790f82f2ce.
{
  android-tools,
  copyDesktopItems,
  fetchFromGitHub,
  flutter347,
  lib,
  makeDesktopItem,
  mpv-unwrapped,
  nix-update,
  nix,
  gh,
  python3,
  yq-go,
  writeShellApplication,
  p7zip,
  protobuf,
  pkg-config,
  rinf_cli,
  rustPlatform,
  stdenvNoCC,
  writeText,
  zstd,
}: let
  pname = "yaas";
  version = "0-unstable-2026-10-29";

  src = fetchFromGitHub {
    owner = "skrimix";
    repo = "yaas";
    rev = "40e061d718b95aadd73caf1f8d81753e001c3885";
    hash = "sha256-JTEmMyALJWKL5o/0J0C9DRkSIFd+EGeOKI5bx58D5Ks=";
  };

  rustDep = rustPlatform.buildRustPackage {
    inherit pname version src;

    buildAndTestSubdir = "native/hub";

    cargoHash = "sha256-k551dTlNoMaav/XlBUWxBi6cfmCPVx9xiMrbNeJ3lVA=";

    nativeBuildInputs = [pkg-config];
    buildInputs = [(zstd.override {enableStatic = true;})];

    doCheck = false;

    passthru.libraryPath = "lib/libhub.so";
  };
in
  flutter347.buildFlutterApplication {
    inherit pname version src;

    # Committed JSON, not autoPubspecLock: that reads ${src}/pubspec.lock during
    # evaluation (import-from-derivation), which the release gate's no-build
    # retained-root evaluation cannot realise. Regenerate after a bump with
    #   yq -o=json . "$(nix build --no-link --print-out-paths .#yaas.src)/pubspec.lock" > pkgs/yaas/pubspec.lock.json
    pubspecLock = lib.importJSON ./pubspec.lock.json;

    customSourceBuilders = {
      rinf = {
        src,
        version,
        ...
      }:
        stdenvNoCC.mkDerivation {
          pname = "rinf";
          inherit version src;

          postPatch = let
            fakeCargokitCmake = writeText "FakeCargokit.cmake" ''
              function(apply_cargokit target manifest_dir lib_name any_symbol_name)
                set("''${target}_cargokit_lib" ${rustDep}/${rustDep.passthru.libraryPath} PARENT_SCOPE)
              endfunction()
            '';
          in ''
            cp ${fakeCargokitCmake} cargokit/cmake/cargokit.cmake
          '';

          installPhase = ''
            runHook preInstall

            cp --recursive . $out

            runHook postInstall
          '';

          inherit (src) passthru;
        };

      media_kit_video = {
        src,
        version,
        ...
      }:
        stdenvNoCC.mkDerivation {
          pname = "media_kit_video";
          inherit version src;

          dontBuild = true;

          postPatch = ''
            # avoid `mpv.pc`'s private dependency chain; the plugin only needs headers and `libmpv`
            substituteInPlace linux/CMakeLists.txt \
              --replace-fail "pkg_check_modules(mpv IMPORTED_TARGET mpv)" "
            add_library(PkgConfig::mpv INTERFACE IMPORTED)
            set_target_properties(PkgConfig::mpv PROPERTIES
              INTERFACE_INCLUDE_DIRECTORIES ${lib.getDev mpv-unwrapped}/include
              INTERFACE_LINK_LIBRARIES ${lib.getLib mpv-unwrapped}/lib/libmpv.so
            )
            set(mpv_INCLUDE_DIRS ${lib.getDev mpv-unwrapped}/include)
            set(mpv_CFLAGS_OTHER \"\")
            "
          '';

          installPhase = ''
            runHook preInstall

            cp --recursive . $out

            runHook postInstall
          '';

          inherit (src) passthru;
        };
    };

    strictDeps = true;

    nativeBuildInputs = [
      copyDesktopItems
      protobuf
      rinf_cli
    ];

    buildInputs = [mpv-unwrapped];

    preBuild = "${lib.getExe rinf_cli} gen";

    postInstall = ''
      install -D --mode=644 ${src}/assets/png/app_icon.png $out/share/icons/hicolor/512x512/apps/yaas.png

      # rinf expects its Rust symbols to be visible to the process on Linux
      patchelf --add-needed libhub.so $out/app/${pname}/yaas
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "yaas";
        desktopName = "YAAS";
        genericName = "Meta Quest sideloader";
        exec = "yaas";
        icon = "yaas";
        categories = ["Utility"];
      })
    ];

    extraWrapProgramArgs = "--prefix PATH : ${lib.makeBinPath [
      android-tools
      p7zip
    ]}";

    passthru = {
      # expose the nested rust dependencies so `nix-update` can refresh `cargoHash`
      inherit (rustDep) cargoDeps;

      # upstream only publishes a mutable nightly prerelease; follow `master` instead
      updateScript.command = [
        (lib.getExe (writeShellApplication {
          name = "update-yaas";
          runtimeInputs = [gh nix nix-update python3 yq-go];
          text = ''
            exec python3 ${./update.py} --root "$PWD" --apply "$@"
          '';
        }))
      ];
    };

    meta = {
      description = "Cross-platform desktop app for sideloading and managing Meta Quest headsets";
      homepage = "https://github.com/skrimix/yaas";
      license = lib.licenses.mit;
      mainProgram = "yaas";
      platforms = ["x86_64-linux"];
    };
  }
