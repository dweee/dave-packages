{
  lib,
  stdenv,
  rustPlatform,
  source,
  cargo-tauri,
  pkg-config,
  cmake,
  bun,
  bun2nix,
  jq,
  nodejs,
  swift,
  cctools,
  apple-sdk_26,
  webkitgtk_4_1,
  gtk3,
  glib,
  libsoup_3,
  alsa-lib,
  libayatana-appindicator,
  libevdev,
  libxtst,
  gtk-layer-shell,
  openssl,
  sqlite,
  vulkan-loader,
  vulkan-headers,
  shaderc,
  spirv-headers,
  gst_all_1,
  glib-networking,
  libx11,
  pipewire,
  alsa-plugins,
  wrapGAppsHook4,
  symlinkJoin,
  writableTmpDirAsHomeHook,
}:
let
  inherit (stdenv.hostPlatform) isLinux isDarwin;
  gstPlugins = lib.optionals isLinux (
    with gst_all_1;
    [
      gstreamer
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
      gst-plugins-ugly
    ]
  );
  combinedAlsaPlugins = symlinkJoin {
    name = "combined-alsa-plugins";
    paths = [
      "${pipewire}/lib/alsa-lib"
      "${alsa-plugins}/lib/alsa-lib"
    ];
  };
  buildEnv = {
    OPENSSL_NO_VENDOR = "1";
  }
  // lib.optionalAttrs isLinux {
    GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins;
  }
  // lib.optionalAttrs isDarwin {
    SWIFTC = lib.getExe' swift "swiftc";
    # FoundationModels' compiler macros are available only in full Xcode.
    # Local GGUF transcription still uses the native Metal backend.
    HANDY_FORCE_AI_STUB = "1";
  };
in
rustPlatform.buildRustPackage {
  pname = "handy";
  version = (lib.importTOML (source + "/src-tauri/Cargo.toml")).package.version;
  src = lib.cleanSourceWith {
    src = source;
    filter =
      path: _type:
      !(builtins.elem (baseNameOf path) [
        ".github"
        "flake.nix"
        "flake.lock"
        "nix"
      ]);
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  tauriBundleType = if isDarwin then "app" else "deb";
  cargoLock = {
    lockFile = source + "/src-tauri/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  bunDeps = bun2nix.fetchBunDeps { bunNix = source + "/.nix/bun.nix"; };
  nativeBuildInputs = [
    cargo-tauri.hook
    pkg-config
    bun
    bun2nix.hook
    jq
    cmake
    nodejs
    rustPlatform.bindgenHook
    writableTmpDirAsHomeHook
  ]
  ++ lib.optionals isLinux [
    wrapGAppsHook4
    shaderc
    spirv-headers
  ]
  ++ lib.optionals isDarwin [
    cctools
    swift
    apple-sdk_26
  ];
  buildInputs = [
    openssl
    sqlite
  ]
  ++ gstPlugins
  ++ lib.optionals isLinux [
    webkitgtk_4_1
    gtk3
    glib
    libsoup_3
    alsa-lib
    libayatana-appindicator
    libevdev
    libxtst
    gtk-layer-shell
    vulkan-loader
    vulkan-headers
    glib-networking
    libx11
  ];

  env = buildEnv;
  passthru.devEnv = buildEnv;

  postPatch = ''
    ${lib.getExe jq} '
      .bundle.createUpdaterArtifacts = false |
      .bundle.macOS.signingIdentity = null |
      .bundle.macOS.hardenedRuntime = false
    ' src-tauri/tauri.conf.json > "$TMPDIR/tauri.conf.json"
    cp "$TMPDIR/tauri.conf.json" src-tauri/tauri.conf.json
    ${lib.getExe jq} 'del(.scripts.postinstall)' package.json > "$TMPDIR/package.json"
    cp "$TMPDIR/package.json" package.json

    # Disable self-update for both CLI and Finder launches from the Nix store.
    substituteInPlace src-tauri/src/settings.rs \
      --replace-fail 'utils::env_flag_enabled("HANDY_DISABLE_UPDATER")' 'true'

    # ferrous-opencc 0.2.3 invokes cargo metadata through cbindgen in the sandbox.
    substituteInPlace "$cargoDepsCopy"/ferrous-opencc-0.2.3/build.rs \
      --replace-fail '.expect("Unable to generate bindings")' '.ok();' \
      --replace-fail '.write_to_file("opencc.h");' '// skipped'
  ''
  + lib.optionalString isLinux ''
    substituteInPlace "$cargoDepsCopy"/libappindicator-sys-*/src/lib.rs \
      --replace-fail 'libayatana-appindicator3.so.1' \
        '${libayatana-appindicator}/lib/libayatana-appindicator3.so.1'
  '';

  preBuild = lib.optionalString isLinux ''
    export CMAKE_PREFIX_PATH="${spirv-headers}''${CMAKE_PREFIX_PATH:+:''${CMAKE_PREFIX_PATH}}"
    export NIX_CFLAGS_COMPILE="-isystem ${spirv-headers}/include ''${NIX_CFLAGS_COMPILE:-}"
  '';
  postInstall = lib.optionalString isDarwin ''
    mkdir -p "$out/bin"
    ln -s "$out/Applications/Handy.app/Contents/MacOS/handy" "$out/bin/handy"
  '';
  preFixup = lib.optionalString isLinux ''
    gappsWrapperArgs+=(
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      --set ALSA_PLUGIN_DIR "${combinedAlsaPlugins}"
    )
  '';

  # Runtime tests need audio devices, a window server and downloaded models.
  doCheck = false;
  meta = {
    description = "Offline speech-to-text application";
    homepage = "https://github.com/cjpais/Handy";
    license = lib.licenses.mit;
    mainProgram = "handy";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
