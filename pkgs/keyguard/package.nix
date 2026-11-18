# Vendored from nixpkgs PR #495316 (keyguard 2.3.4 -> 3.2.0, by ilkecan) and
# bumped to 3.2.3 with macOS support. Drop this and the tempfixes overlay
# entry once nixpkgs supplies equivalent packaging and the Linux JDK-8312488 fix.
{
  lib,
  stdenv,
  alsa-lib,
  autoPatchelfHook,
  callPackage,
  cups,
  fetchFromGitHub,
  file,
  fontconfig,
  glib,
  gradle-packages,
  gradle_9,
  gtk3,
  jetbrains, # https://github.com/AChep/keyguard-app/commit/e0627190abfd94d9367dec42c39c991d378c3660
  lcms2,
  libglvnd,
  libxinerama,
  libxrandr,
  makeWrapper,
  stripJavaArchivesHook,
  writeText,
}: let
  jbr =
    if stdenv.hostPlatform.isDarwin
    then callPackage ./jbr-darwin.nix {}
    else jetbrains.jdk-no-jcef-21;
  # deps.json includes the Kotlin DSL plugin shipped with Gradle 9.7.1.
  # Keep the build tool aligned with that cache when nixpkgs updates gradle_9.
  gradleBase = gradle-packages.mkGradle {
    version = "9.7.1";
    hash = "sha256-rNU/HtrwLxqP+Zh5+KNLMCZhoFfZsGOunjW1UvgE0go=";
    defaultJava = gradle_9.jdk;
  };
  gradle = gradleBase.wrapped.override {javaToolchains = [jbr.home];};
  libraryExtension = stdenv.hostPlatform.extensions.sharedLibrary;
  appResources =
    if stdenv.hostPlatform.isDarwin
    then "Applications/Keyguard.app/Contents/app/resources"
    else "lib/app/resources";
in
  stdenv.mkDerivation (
    finalAttrs: let
      dependencyCache = gradle.fetchDeps {
        pkg = finalAttrs.finalPackage;
        data = ./deps.json;
        silent = false;
        useBwrap = false;
      };
    in {
      pname = "keyguard";
      version = "3.2.3";

      src = fetchFromGitHub {
        owner = "AChep";
        repo = "keyguard-app";
        tag = "r20260916";
        hash = "sha256-+uyNoBBDbKJXgWYDCfiwhUsV+n77yU8u0K5EfcWG2q8=";
      };

      postPatch = ''
        substituteInPlace desktopApp/build.gradle.kts \
          --replace-fail 'dependsOn(prepareBundledAppResources)' ""

        # Resolve all desktop runtime variants without spoofing the host JVM's OS
        # or architecture (which also affects Gradle's own native services).
        if [ "''${IN_GRADLE_UPDATE_DEPS:-}" = 1 ]; then
          substituteInPlace desktopApp/build.gradle.kts \
            --replace-fail 'implementation(compose.desktop.currentOs)' '
              implementation(compose.desktop.currentOs)
              implementation(compose.desktop.linux_x64)
              implementation(compose.desktop.linux_arm64)
              implementation(compose.desktop.macos_x64)
              implementation(compose.desktop.macos_arm64)'
        fi

        # The Compose repository must not shadow dependencies published by Maven Central.
        substituteInPlace settings.gradle \
          --replace-fail \
            'maven { url "https://maven.pkg.jetbrains.space/public/p/compose/dev" }' \
            'maven {
              url "https://maven.pkg.jetbrains.space/public/p/compose/dev"
              content {
                includeGroupByRegex "org[.]jetbrains[.]compose([.].*)?"
                includeGroupByRegex "org[.]jetbrains[.]androidx([.].*)?"
              }
            }'
      ''
      + lib.optionalString stdenv.hostPlatform.isLinux ''
        # Linux runners have limited swap. Bound Gradle so its JVM does not
        # compound the memory used while Nix processes the dependency graph.
        # Kotlin compiles inside this one bounded JVM (see gradleFlags): a separate
        # 1 GiB Kotlin daemon cannot compile :common, and metadata compilation
        # exhausts a 384 MiB metaspace. The gradle hook splits gradleFlags on
        # whitespace, so a multi-option jvmargs value has to live here instead.
        substituteInPlace gradle.properties \
          --replace-fail \
            'org.gradle.jvmargs=-Xmx4096m -Dfile.encoding=UTF-8' \
            'org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:+UseSerialGC -Dfile.encoding=UTF-8'
      '';

      preBuild = ''
        export ANDROID_USER_HOME="$TMPDIR/.android"
        export KONAN_DATA_DIR="$TMPDIR/.konan"
        mkdir -p "$ANDROID_USER_HOME" "$KONAN_DATA_DIR"

        ${lib.optionalString stdenv.hostPlatform.isDarwin ''
          # Kotlin/Native's downloader does not replay through the Gradle proxy.
          # Let its own extractor consume the same hash-pinned LLVM/libffi archives.
          if [ "''${IN_GRADLE_UPDATE_DEPS:-}" != 1 ]; then
            mkdir -p "$KONAN_DATA_DIR/dependencies/cache"
            find ${finalAttrs.mitmCache}/https/download.jetbrains.com/kotlin/native \
              -name '*.tar.gz' -exec cp -L {} "$KONAN_DATA_DIR/dependencies/cache/" \;
          fi
        ''}

        # Build the native helpers with Nix, then let Compose copy and verify them
        # using upstream's app-resource layout and executable-permission repair.
        resources=desktopApp/build/app-resources/${
          if stdenv.hostPlatform.isDarwin
          then "macos"
          else "linux"
        }-${
          if stdenv.hostPlatform.isAarch64
          then "arm64"
          else "x64"
        }
        mkdir -p "$resources"
        install -m755 ${finalAttrs.passthru.sshAgent}/bin/keyguard-ssh-agent "$resources/keyguard-ssh-agent"
        install -m755 ${finalAttrs.passthru.gpgAgent}/bin/keyguard-gpg-agent "$resources/keyguard-gpg-agent"
        install -m755 ${finalAttrs.passthru.libNative}/lib/libkeyguard${libraryExtension} "$resources/keyguard-lib"
        install -m755 ${finalAttrs.passthru.crypto}/lib/libkeyguard_crypto_jni${libraryExtension} "$resources/"
        install -m755 ${finalAttrs.passthru.io}/lib/libkeyguard_io_jni${libraryExtension} "$resources/"
        install -m755 ${finalAttrs.passthru.instance}/lib/libkeyguard_instance_jni${libraryExtension} "$resources/"
        install -m755 ${finalAttrs.passthru.zxcvbn}/lib/libkeyguard_zxcvbn_jni${libraryExtension} "$resources/"
      '';

      gradleBuildTask = ":desktopApp:createReleaseDistributable";

      gradleUpdateTask = finalAttrs.gradleBuildTask;

      # Fetch all desktop runtimes and retain the native-toolchain archives that
      # were recorded on other hosts. Kotlin/Native downloads only its host bundle.
      postGradleUpdate = ''
        gradle :desktopApp:nixDownloadDeps
        jq -r 'keys[] | select(endswith(".tar.gz"))' ${dependencyCache.data} |
          while IFS= read -r archiveUrl; do
            curl --fail --location --output /dev/null "$archiveUrl"
          done
      '';

      gradleInitScript = writeText "empty-init-script.gradle" "";

      mitmCache = dependencyCache;

      nativeBuildInputs =
        [
          gradle
          jbr
          stripJavaArchivesHook
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook]
        ++ lib.optionals stdenv.hostPlatform.isDarwin [makeWrapper];

      # The Gradle hook replays pinned dependencies through a loopback proxy.
      __darwinAllowLocalNetworking = true;

      buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
        fontconfig
        libxinerama
        libxrandr
        file
        gtk3
        glib
        cups
        lcms2
        alsa-lib
        libglvnd
      ];

      doCheck = false;

      # jpackage signs the macOS launcher/runtime; stripping them breaks signatures.
      dontStrip = stdenv.hostPlatform.isDarwin;

      installPhase = ''
        runHook preInstall

        ${lib.optionalString stdenv.hostPlatform.isDarwin ''
          mkdir -p "$out/Applications" "$out/bin"
          cp -R desktopApp/build/compose/binaries/main-release/app/Keyguard.app "$out/Applications/"
          makeWrapper "$out/Applications/Keyguard.app/Contents/MacOS/Keyguard" "$out/bin/Keyguard"
          appConfig="$out/Applications/Keyguard.app/Contents/app/Keyguard.cfg"
        ''}
        ${lib.optionalString stdenv.hostPlatform.isLinux ''
          cp --recursive desktopApp/build/compose/binaries/main-release/app/Keyguard "$out"
          appConfig="$out/lib/app/Keyguard.cfg"
          install -D --mode=0644 "$out/lib/Keyguard.png" "$out/share/icons/hicolor/512x512/apps/keyguard.png"
          install -Dm444 -t "$out/share/applications/" desktopApp/flatpak/*.desktop
          install -Dm444 desktopApp/flatpak/icon.svg "$out/share/icons/hicolor/scalable/apps/com.artemchep.keyguard.svg"
          install -Dm444 -t "$out/share/metainfo/" desktopApp/flatpak/*.metainfo.xml
        ''}

        # Fail if Compose changes the layout expected by the native-library loader.
        grep -Fqx 'java-options=-Dcompose.application.resources.dir=$APPDIR/resources' "$appConfig"
        for helper in keyguard-ssh-agent keyguard-gpg-agent keyguard-lib; do
          test -x "$out/${appResources}/$helper"
        done

        runHook postInstall
      '';

      # Jar normalization changes sealed resources. Re-seal only the two bundle
      # roots, preserving upstream's JVM entitlements and hardened-runtime flags.
      postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
        for bundle in "$out/Applications/Keyguard.app/Contents/runtime" "$out/Applications/Keyguard.app"; do
          /usr/bin/codesign --force --sign - \
            --preserve-metadata=identifier,entitlements,flags,runtime "$bundle"
        done
        /usr/bin/codesign --verify --strict --deep "$out/Applications/Keyguard.app"
      '';

      passthru = {
        # CI realises and publishes the patched JBR in its own process.
        inherit jbr;
        crypto = callPackage ./crypto.nix {inherit (finalAttrs) src version;};
        gpgAgent = callPackage ./gpg-agent.nix {inherit (finalAttrs) src version;};
        instance = callPackage ./instance.nix {inherit (finalAttrs) src version;};
        io = callPackage ./io.nix {inherit (finalAttrs) src version;};
        libNative = callPackage ./lib-native.nix {inherit (finalAttrs) src version;};
        sshAgent = callPackage ./ssh-agent.nix {inherit (finalAttrs) src version;};
        zxcvbn = callPackage ./zxcvbn.nix {inherit (finalAttrs) src version;};
      };

      meta = {
        description = "Alternative client for the Bitwarden platform, created to provide the best user experience possible";
        homepage = "https://github.com/AChep/keyguard-app";
        changelog = "https://github.com/AChep/keyguard-app/releases/tag/${finalAttrs.src.tag}";
        mainProgram = "Keyguard";
        license = lib.licenses.unfree;
        sourceProvenance = with lib.sourceTypes; [
          fromSource # Keyguard and bundled helpers
          binaryBytecode # mitm cache
          binaryNativeCode # JNA, SQLite JDBC, Skiko and the macOS JBR SDK
        ];
        platforms = lib.platforms.linux ++ lib.platforms.darwin;
      };
    }
    // lib.optionalAttrs stdenv.hostPlatform.isLinux {
      # Run one Gradle worker and compile Kotlin in the Gradle JVM, whose heap is
      # capped in postPatch. Darwin already fits and must keep its existing output.
      gradleFlags = [
        "-Dorg.gradle.workers.max=1"
        "-Pkotlin.compiler.execution.strategy=in-process"
      ];
    }
  )
