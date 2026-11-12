{
  lib,
  aws-lc,
  qt6,
  kdePackages,
  bzip2,
  stdenv,
  buildPackages,
  writeText,
}: let
  pin = lib.importJSON ./pin.json;
  # An immutable evaluator fetch keeps upstream's recipe/Cargo.lock available
  # without a build-time import or another independently pinned nixpkgs.
  source =
    (builtins.fetchTree {
      type = "github";
      owner = "Mizerd";
      repo = "lightning";
      rev = pin.revision;
      narHash = pin.hash;
    }).outPath;
  isDarwin = stdenv.hostPlatform.isDarwin;
  darwinKdePackages = kdePackages.overrideScope (_: kp:
    lib.genAttrs ["extra-cmake-modules" "karchive" "kimageformats"] (name:
      kp.${name}.overrideAttrs (old:
        {meta = old.meta // {platforms = lib.unique (old.meta.platforms ++ lib.platforms.darwin);};}
        // lib.optionalAttrs (name == "karchive") {
          buildInputs = old.buildInputs ++ [bzip2];
        })));
  upstream = qt6.callPackage "${source}/nix/package.nix" ({version = pin.version;}
    // lib.optionalAttrs isDarwin {
      pipewire = null;
      qt6 = qt6 // {qtwayland = null;};
      kdePackages = darwinKdePackages;
    });
  appName = "Lightning";
  infoPlist = writeText "Info.plist" (lib.generators.toPlist {escape = true;} {
    CFBundleDevelopmentRegion = "en";
    CFBundleDisplayName = appName;
    CFBundleExecutable = appName;
    CFBundleIconFile = appName;
    CFBundleIdentifier = "net.smetonis.lightning";
    CFBundlePackageType = "APPL";
    CFBundleShortVersionString = pin.version;
    CFBundleVersion = pin.version;
    LSMinimumSystemVersion = stdenv.hostPlatform.darwinMinVersion;
    LSApplicationCategoryType = "public.app-category.social-networking";
    NSHighResolutionCapable = true;
    NSHumanReadableCopyright = "Copyright (C) 2026 Rokas Smetonis. GPL-3.0-or-later.";
    NSMicrophoneUsageDescription = "Lightning needs the microphone to record voice messages.";
    NSAudioCaptureUsageDescription = "Lightning captures system audio only when you share your screen with sound.";
    NSCameraUsageDescription = "Lightning needs the camera only if you attach a photo or video you capture.";
  });
in
  upstream.overrideAttrs (old:
    {
      # aws-lc-sys uses the installed headers, shared libraries and generated
      # Rust bindings through pkg-config's split-output layout.
      buildInputs = (old.buildInputs or []) ++ [aws-lc];
      passthru = (old.passthru or {}) // {inherit source;};
      meta = old.meta // {platforms = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];};
    }
    // lib.optionalAttrs isDarwin {
      nativeBuildInputs = old.nativeBuildInputs ++ [buildPackages.libicns];
      postInstall =
        (old.postInstall or "")
        + ''
          contents=$out/Applications/${appName}.app/Contents
          mkdir -p "$contents/MacOS" "$contents/Resources"
          mv "$out/bin/lightning-matrix" "$contents/MacOS/${appName}"
          cp ${infoPlist} "$contents/Info.plist"
          png2icns "$contents/Resources/${appName}.icns" ${lib.concatMapStringsSep " " (size: "$out/share/icons/hicolor/${size}x${size}/apps/lightning.png") ["16" "32" "48" "128" "256" "512"]}
        '';
      postFixup =
        (old.postFixup or "")
        + ''
          ln -s "$out/Applications/${appName}.app/Contents/MacOS/${appName}" "$out/bin/lightning-matrix"
        '';
    })
