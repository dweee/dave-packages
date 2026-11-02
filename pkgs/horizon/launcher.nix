# The Horizon launcher, built from source: it installs, prepares and starts
# Horizon builds, hosts servers and builds native mods. On Linux, use it
# through ./fhs.nix: the game builds it downloads are ordinary Linux programs.
#
# `pin` is one entry of ./sources.json. For nixpkgs, inline its fields.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  alsa-lib,
  fontconfig,
  freetype,
  libGL,
  libxkbcommon,
  openssl,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  pin,
}:

let
  runtimeLibraries = [
    libGL
    libxkbcommon
    vulkan-loader
    wayland
    libx11
    libxcb
    libxcursor
    libxi
    libxrandr
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "horizon-launcher";
  inherit (pin) version cargoHash;

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "horizon-rust";
    repo = "horizon";
    inherit (pin) rev hash;
  };

  cargoRoot = "launcher";
  buildAndTestSubdir = "launcher";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    alsa-lib
    fontconfig
    freetype
    libxkbcommon
    libxcb
    wayland
  ];

  # gpui compiles its Metal shaders with Xcode's `metal` tool unless they are
  # compiled at run time, which the sandbox needs (as nixpkgs' Zed does).
  buildFeatures = lib.optional stdenv.hostPlatform.isDarwin "gpui_platform/runtime_shaders";

  env = {
    OPENSSL_NO_VENDOR = true;
    # launcher.yml's build: the release line it is on and the version it says.
    HORIZON_LAUNCHER_VERSION = pin.release or "";
    HORIZON_LAUNCHER_TAG = lib.optionalString (pin ? release) "launcher@${pin.release}";
  };

  # The UI tests need a display.
  doCheck = false;

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    mkdir -p $out/share/icons
    cp -r packaging/icons/hicolor $out/share/icons/
    install -Dm644 -t $out/share/applications packaging/linux/horizon-launcher.desktop
  '';

  postFixup = ''
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      patchelf --add-rpath ${lib.makeLibraryPath runtimeLibraries} $out/bin/horizon-launcher
    ''}
    # A package updates through Nix, not by replacing its own binary.
    wrapProgram $out/bin/horizon-launcher --set-default HORIZON_LAUNCHER_NO_SELF_UPDATE 1
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/horizon-launcher --version
    runHook postInstallCheck
  '';

  passthru = { inherit pin; };

  meta = {
    description = "Launcher for Horizon, Minecraft: Java Edition 26.3 rewritten in Rust";
    longDescription = ''
      Downloads Horizon Nightlies, prepares their game files from your own
      legally obtained copy of Minecraft, starts the game, hosts servers and
      builds native mods. Not an official Minecraft product; not approved by
      or associated with Mojang or Microsoft.
    '';
    homepage = "https://playhorizon.dev";
    changelog = "https://github.com/horizon-rust/horizon/releases";
    license = lib.licenses.mit;
    mainProgram = "horizon-launcher";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
