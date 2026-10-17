{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  makeWrapper,
  dolphin-emu,
  fontconfig,
  icu,
  krb5,
  libglvnd,
  libice,
  libsm,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxkbcommon,
  libxrandr,
  openssl,
  wayland,
  zlib,
  undmg,
}: let
  pname = "wheelwizard";
  version = "2.6.2";

  # Official self-contained Avalonia/.NET 10 builds. nixpkgs#wheelwizard is
  # still 2.4.11 (.NET 8); nixpkgs PR 557011 is 2.5.1 from source. Drop this
  # recipe when the flake pin ships >= 2.5.2 (Linux) and a darwin .app.
  linuxSources = {
    x86_64-linux = {
      url = "https://github.com/TeamWheelWizard/WheelWizard/releases/download/v${version}/WheelWizard_Linux";
      hash = "sha256-FAPl0ZcFYgk4VR6EUROQlc6ZcJNCH+K4xYPzvhI3k2E=";
    };
    aarch64-linux = {
      url = "https://github.com/TeamWheelWizard/WheelWizard/releases/download/v${version}/WheelWizard_arm64_Linux";
      hash = "sha256-6+uK/ul8QhLA+ptVqnWSLzvknr7xMalfU2gMU0TytRM=";
    };
  };

  darwinSources = {
    aarch64-darwin = {
      url = "https://github.com/TeamWheelWizard/WheelWizard/releases/download/v${version}/WheelWizard-macOSarm64.dmg";
      hash = "sha256-iHidZrX6RkcuGinAHPxkFqA0JkcJE3CbFhvbnDgR6Pw=";
    };
    x86_64-darwin = {
      url = "https://github.com/TeamWheelWizard/WheelWizard/releases/download/v${version}/WheelWizard-macOSintel.dmg";
      hash = "sha256-YGPfR/knr75LQr+7edUD9/27AA/UroMEblV07S2ULvE=";
    };
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/TeamWheelWizard/WheelWizard/v${version}/Flatpak/io.github.TeamWheelWizard.WheelWizard.png";
    hash = "sha256-0FWum5kdqU0BZZjZPjbwF3xglZgAEkDMbK6W9uVkoe4=";
  };

  packageMeta = {
    description = "Mario Kart Wii mod manager and Retro Rewind launcher";
    homepage = "https://github.com/TeamWheelWizard/WheelWizard";
    changelog = "https://github.com/TeamWheelWizard/WheelWizard/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    mainProgram = "WheelWizard";
  };
in
  if stdenv.hostPlatform.isDarwin
  then
    stdenvNoCC.mkDerivation rec {
      inherit pname version;

      src = fetchurl {
        inherit (darwinSources.${stdenv.hostPlatform.system}) url hash;
      };

      nativeBuildInputs = [undmg makeWrapper];

      sourceRoot = ".";

      installPhase = ''
        runHook preInstall
        mkdir -p $out/Applications $out/bin
        app=$(find . -maxdepth 2 -name '*.app' -print -quit)
        cp -R "$app" $out/Applications/
        plist=$out/Applications/$(basename "$app")/Contents/Info.plist
        exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
        inner=$out/Applications/$(basename "$app")/Contents/MacOS
        mv "$inner/$exe" "$inner/.$exe-unwrapped"
        makeWrapper "$inner/.$exe-unwrapped" "$inner/$exe" \
          --prefix PATH : ${lib.makeBinPath [dolphin-emu]}
        ln -s "$inner/$exe" $out/bin/WheelWizard
        ln -s WheelWizard $out/bin/wheel-wizard
        runHook postInstall
      '';

      meta = packageMeta // {platforms = lib.attrNames darwinSources;};
    }
  else let
    src =
      linuxSources.${stdenv.hostPlatform.system}
      or (throw "${pname}: unsupported system ${stdenv.hostPlatform.system}");

    runtimeLibs = [
      fontconfig
      icu
      krb5
      libglvnd
      libxkbcommon
      openssl
      stdenv.cc.cc.lib
      wayland
      libice
      libsm
      libx11
      libxcursor
      libxext
      libxi
      libxrandr
      zlib
    ];
  in
    stdenv.mkDerivation {
      inherit pname version;

      src = fetchurl {
        inherit (src) url hash;
      };

      nativeBuildInputs = [
        autoPatchelfHook
        copyDesktopItems
        makeWrapper
      ];

      buildInputs = runtimeLibs;

      dontUnpack = true;
      dontStrip = true;

      desktopItems = [
        (makeDesktopItem {
          name = "io.github.TeamWheelWizard.WheelWizard";
          desktopName = "Wheel Wizard";
          exec = "WheelWizard";
          icon = "io.github.TeamWheelWizard.WheelWizard";
          comment = "Mario Kart Wii Mod Manager & Retro Rewind Auto Updater";
          genericName = "Mario Kart Wii Mod Manager";
          categories = ["Game"];
          startupWMClass = "WheelWizard";
        })
        (makeDesktopItem {
          name = "io.github.TeamWheelWizard.WheelWizard-url-handler";
          desktopName = "Wheel Wizard – URL Handler";
          exec = "WheelWizard %U";
          icon = "io.github.TeamWheelWizard.WheelWizard";
          comment = "Mario Kart Wii Mod Manager & Retro Rewind Auto Updater";
          genericName = "Mario Kart Wii Mod Manager";
          categories = ["Game"];
          startupWMClass = "WheelWizard";
          mimeTypes = ["x-scheme-handler/wheelwizard"];
          noDisplay = true;
          extraConfig.StartupNotify = "true";
        })
      ];

      installPhase = ''
        runHook preInstall
        install -Dm755 $src $out/libexec/wheelwizard/WheelWizard
        install -Dm644 ${icon} $out/share/icons/hicolor/256x256/apps/io.github.TeamWheelWizard.WheelWizard.png
        runHook postInstall
      '';

      # Wheel Wizard locates Dolphin with `command -v` (EnvHelper). Keep the
      # nixpkgs emulator on PATH; do not let the in-app installer fetch a FHS binary.
      postFixup = ''
        makeWrapper $out/libexec/wheelwizard/WheelWizard $out/bin/WheelWizard \
          --prefix PATH : ${lib.makeBinPath [dolphin-emu]} \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
        ln -s WheelWizard $out/bin/wheel-wizard
      '';

      meta = packageMeta // {platforms = lib.attrNames linuxSources;};
    }
