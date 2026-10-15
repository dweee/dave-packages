{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchNpmDeps,
  cargo-tauri,
  nodejs,
  npmHooks,
  pkg-config,
  wrapGAppsHook3,
  glib-networking,
  gst_all_1,
  libayatana-appindicator,
  openssl,
  pipewire,
  pulseaudio,
  systemdLibs,
  webkitgtk_4_1,
  xdg-utils,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openghub";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "Slyvan25";
    repo = "OpenGHub";
    tag = "v${finalAttrs.version}";
    hash = "sha256-szNHEZ6fSPkEtIPnfhP6xpQ9IYwxyVl4In6EzrfG+40=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-o20rsU94aDi38WD6/GLEBK1pnfb9XSq92XiuOG335ko=";

  # Upstream's full LTO and single codegen unit exceed the bounded fleet
  # builder's source-build budget. Keep release optimization, with parallel
  # code generation and no cross-crate link-time optimization.
  env = {
    CARGO_PROFILE_RELEASE_LTO = "off";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    hash = "sha256-f2s1c+eIIIGqXMLuNWCHxP0zZ+mCPymxxAZTZ/mqs+Y=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    npmHooks.npmConfigHook
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    glib-networking
    # The deb bundler refuses to run without it on pkg-config.
    libayatana-appindicator
    openssl
    systemdLibs
    webkitgtk_4_1
    # LIGHTSYNC screen sampler: gst-launch-1.0 + pipewiresrc.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    pipewire
  ];

  # Unit tests need hidraw and a writable $HOME; the build is what matters here.
  doCheck = false;

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          gst_all_1.gstreamer
          pulseaudio
          xdg-utils
        ]
      }
    )
  '';

  # Tray icon: tauri dlopens libayatana-appindicator3 and panics at startup
  # without it. Patch the real binary (not the gapps wrapper), after
  # patchelf's RPATH shrink, which would drop an entry nothing DT_NEEDs.
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath [ libayatana-appindicator ]} $out/bin/.openghub-wrapped
  '';

  meta = {
    description = "Open source Logitech G HUB for Linux (HID++ 2.0 over hidraw)";
    homepage = "https://github.com/Slyvan25/OpenGHub";
    license = lib.licenses.mit;
    mainProgram = "openghub";
    platforms = lib.platforms.linux;
  };
})
