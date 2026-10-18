{
  lib,
  stdenv,
  fetchFromGitHub,
  callPackage,
  python3,
  pkgs,
  ffmpeg,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  qt6,
}: let
  # Lapwolf enables ROCm globally. Keep this CPU-first app on the cached CPU
  # Python closure instead of rebuilding torch/ONNX with the host's GPU policy.
  python =
    if stdenv.hostPlatform.isLinux && ((pkgs.config.rocmSupport or false) || (pkgs.config.cudaSupport or false))
    then
      (import pkgs.path {
        system = stdenv.hostPlatform.system;
        config = {
          allowUnfree = true;
          rocmSupport = false;
          cudaSupport = false;
        };
      }).python3
    else python3;
  backend = callPackage ./audio-separator.nix {python3 = python;};
  guiPython = python.withPackages (py: [py.pyside6]);
in
  stdenv.mkDerivation {
    pname = "stemlab";
    version = "0.2.0-alpha.1-unstable-2026-10-15";
    src = fetchFromGitHub {
      owner = "808SGN-Labs";
      repo = "stem-separator";
      rev = "a30f6f8ff85e5142c6374496efd0624443976ada";
      hash = "sha256-xwqRpSc4NW9gg6kugSwxXkIHu9CnO1J5UE0/lhBiJ6k=";
    };
    patches = [./case-sensitive-test.patch];
    # These interpreters occur inside generated fixture scripts, so the normal
    # patchShebangs hook cannot see them. NixOS sandboxes lack /usr/bin/env.
    postPatch = ''
      substituteInPlace tests/test_producer_queue.py \
        --replace-fail '#!/usr/bin/env python3' '#!${guiPython}/bin/python' \
        --replace-fail '#!/bin/sh' '#!${stdenv.shell}'
    '';
    nativeBuildInputs =
      [makeWrapper qt6.wrapQtAppsHook]
      ++ lib.optionals stdenv.hostPlatform.isLinux [copyDesktopItems];
    buildInputs = [qt6.qtbase qt6.qtmultimedia];
    dontWrapQtApps = true;
    dontBuild = true;
    doCheck = true;
    nativeCheckInputs = [guiPython ffmpeg];
    checkPhase = ''
      runHook preCheck
      export HOME="$TMPDIR/stemlab-test-home"
      mkdir -p "$HOME"
      export QT_QPA_PLATFORM=offscreen
      ${guiPython}/bin/python -m unittest discover -s tests -p test_offline_wrapper.py -v
      ${guiPython}/bin/python -m unittest discover -s tests -p test_producer_queue.py -v
      runHook postCheck
    '';
    desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
      (makeDesktopItem {
        name = "stemlab";
        desktopName = "StemLab";
        comment = "Separate music into local WAV stems";
        exec = "stemlab";
        categories = ["AudioVideo" "Audio"];
        terminal = false;
      })
    ];
    installPhase =
      ''
        runHook preInstall
        mkdir -p "$out/lib/stemlab/gui" "$out/lib/stemlab/scripts" "$out/bin"
        install -m644 gui/producer_qt.py "$out/lib/stemlab/gui/producer_qt.py"
        install -m755 scripts/stem-separate "$out/lib/stemlab/scripts/stem-separate"
        substituteInPlace "$out/lib/stemlab/scripts/stem-separate" \
          --replace-fail 'SEPARATOR="$VENV/bin/audio-separator"' 'SEPARATOR="${lib.getExe backend}"' \
          --replace-fail '  STEM_LAB_VENV      Override the virtual environment path' '  Backend is managed by Nix; no virtual environment setup is needed.'
        patchShebangs "$out/lib/stemlab/scripts/stem-separate"
        makeWrapper "$out/lib/stemlab/scripts/stem-separate" "$out/bin/stem-separate" \
          --prefix PATH : ${lib.makeBinPath [ffmpeg]}
        makeWrapper ${guiPython}/bin/python "$out/bin/stemlab" \
          --add-flags "$out/lib/stemlab/gui/producer_qt.py" \
          --prefix PATH : ${lib.makeBinPath [ffmpeg]} \
          "''${qtWrapperArgs[@]}"
        install -Dm644 LICENSE-CODE "$out/share/licenses/stemlab/LICENSE-CODE"
      ''
      + lib.optionalString stdenv.hostPlatform.isDarwin ''
        mkdir -p "$out/Applications/StemLab.app/Contents/MacOS"
        ln -s "$out/bin/stemlab" "$out/Applications/StemLab.app/Contents/MacOS/stemlab"
        cat > "$out/Applications/StemLab.app/Contents/Info.plist" <<'EOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>CFBundleName</key><string>StemLab</string>
          <key>CFBundleIdentifier</key><string>com.808sgn.stemlab</string>
          <key>CFBundleExecutable</key><string>stemlab</string>
          <key>CFBundlePackageType</key><string>APPL</string>
          <key>NSHighResolutionCapable</key><true/>
        </dict></plist>
        EOF
      ''
      + ''
        runHook postInstall
      '';
    passthru = {inherit backend guiPython;};
    meta = {
      description = "Local music stem separation with a producer queue and WAV preview";
      homepage = "https://github.com/808SGN-Labs/stem-separator";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-darwin"];
      mainProgram = "stemlab";
    };
  }
