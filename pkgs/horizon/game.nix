# Horizon, Minecraft: Java Edition 26.3 rewritten in Rust, built from source.
#
# One recipe for the two release folders upstream ships (xtask `package` and
# `package-server`): the full game (client, horizon-ctl, horizon-prepare and
# horizon-server) and, with `headless = true`, the dedicated server build
# (the game without sound or controllers as horizon-engine, with
# horizon-prepare and horizon-server). The server build is the one that
# runs on aarch64-linux: upstream publishes no ARM Linux binaries.
#
# `pin` is one entry of ./sources.json. For nixpkgs, inline its fields.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  wrapFolder,
  alsa-lib,
  udev,
  libGL,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  horizon-mixins,
  pin,
  headless ? false,
  # horizon-mixins bundles (folders with a horizon-mixin.toml, or folders of
  # them) applied to the game's source before it is compiled
  # (docs/native-mods.md). Each must keep to the crates Cargo.lock holds.
  nativeMods ? [ ],
}:

let
  # Libraries the game opens at run time rather than links.
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
  linuxDesktop = stdenv.hostPlatform.isLinux && !headless;
  # The server folder names the game horizon-engine (xtask package-server).
  game = if headless then "horizon-engine" else "horizon-client";
  programs = [
    "horizon-prepare"
    "horizon-server"
  ]
  ++ lib.optional (!headless) "horizon-ctl";
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = if headless then "horizon-server" else "horizon";
  inherit (pin) version;

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "horizon-rust";
    repo = "horizon";
    inherit (pin) rev hash;
  };

  inherit (pin) cargoHash;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ]
  ++ lib.optional (nativeMods != [ ]) horizon-mixins;

  buildInputs = lib.optionals linuxDesktop [
    alsa-lib
    udev
  ];

  # game-build.yml's build: the release builds of exactly these programs.
  cargoBuildFlags = [
    "--package=horizon-client"
    "--bin=horizon-client"
    "--package=horizon-prepare"
    "--bin=horizon-prepare"
    "--package=horizon-server"
    "--bin=horizon-server"
  ]
  ++ lib.optional (!headless) "--bin=horizon-ctl";

  # The server build: no audio or controllers, so no libasound or libudev.
  buildNoDefaultFeatures = headless;

  env = {
    # horizon_core::release: what --version, crash reports and the title say.
    HORIZON_VERSION = pin.release or "";
    HORIZON_NIGHTLY = pin.nightly or "";
  };

  # Native mods are applied after cargoSetupHook has checked Cargo.lock
  # against the vendored crates: a bundle may add path crates of its own.
  preBuild =
    lib.optionalString (nativeMods != [ ]) ''
      mkdir -p "$TMPDIR/horizon-native-mods"
      ${lib.concatMapStringsSep "\n" (
        mod: ''cp -r --no-preserve=mode ${mod} "$TMPDIR/horizon-native-mods/"''
      ) nativeMods}
      # As the launcher does: the bundles build on this commit (it rewrites
      # their horizon_revision), which horizon-mixins reads without git here.
      echo ${pin.rev} > .horizon-revision
      find "$TMPDIR/horizon-native-mods" -name horizon-mixin.toml -exec \
        sed -i -E 's/^horizon_revision *=.*/horizon_revision = "${pin.rev}"/' {} +
      # horizon-mixins refuses symlinks in what it stages (CLAUDE.md is one).
      find . -path ./target -prune -o -type l -print | while read -r link; do
        if [ -f "$link" ]; then cp --remove-destination "$(readlink -f "$link")" "$link"; else rm "$link"; fi
      done
      horizon-mixins apply --workspace "$PWD" --mods "$TMPDIR/horizon-native-mods" \
        --out "$TMPDIR/horizon-modded"
      cp -rT --no-preserve=mode "$TMPDIR/horizon-modded" "$PWD"
      # The launcher's builds: horizon-client/mods, where the modded source has it.
      if sed -n '/^\[features\]/,/^\[/p' crates/horizon-client/Cargo.toml | grep -q '^mods *='; then
        cargoBuildFlags+=(--features=horizon-client/mods)
      fi
    ''
    # Upstream 42a5981e set autobins = false in horizon-client and declared
    # horizon-ctl in horizon-client-lib; older pins still have it in
    # horizon-client. Select the package that declares it, as game-build.yml does.
    + lib.optionalString (!headless) ''
      if grep -qs '^name *= *"horizon-ctl"' crates/horizon-client-lib/Cargo.toml; then
        cargoBuildFlags+=(--package=horizon-client-lib)
      fi
    '';

  # The parity harnesses need a prepared vanilla tree, which the sandbox lacks.
  doCheck = false;

  # The release folder layout, as xtask packages it: the programs side by side
  # with what horizon-prepare compiles its exporters from.
  installPhase = ''
    runHook preInstall

    release="target/${stdenv.hostPlatform.rust.cargoShortTarget}/release"
    folder="$out/libexec/horizon"
    mkdir -p "$folder" "$out/bin"

    install -Dm755 "$release/horizon-client" "$folder/${game}"
    for program in ${lib.escapeShellArgs programs}; do
      install -Dm755 "$release/$program" "$folder/$program"
    done
    for path in tools mods/horizon/src/test/java crates/horizon-prepare research-lock.json LICENSE; do
      mkdir -p "$folder/$(dirname "$path")"
      cp -r "$path" "$folder/$path"
    done
    ${lib.optionalString (!headless) ''install -Dm644 packaging/PLAY.txt "$folder/PLAY.txt"''}
    ${lib.optionalString linuxDesktop ''
      mkdir -p $out/share/icons
      cp -r packaging/icons/hicolor $out/share/icons/
      install -Dm644 -t $out/share/applications packaging/linux/horizon.desktop
    ''}

    runHook postInstall
  '';

  postFixup = wrapFolder {
    inherit headless game;
    runtimeLibraries = lib.optionals linuxDesktop runtimeLibraries;
  };

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/horizon-server --version
    $out/libexec/horizon/horizon-prepare --version
    $out/libexec/horizon/${game} --help | grep -q -- --resources
    runHook postInstallCheck
  '';

  passthru = {
    inherit headless nativeMods pin;
    folder = "${finalAttrs.finalPackage}/libexec/horizon";
  };

  meta = {
    description =
      if headless then
        "Dedicated server for Horizon, a native Minecraft: Java Edition 26.3 implementation"
      else
        "Horizon, Minecraft: Java Edition 26.3 rewritten in Rust";
    longDescription = ''
      Horizon is an unofficial native implementation of Minecraft: Java
      Edition 26.3. Its game files are prepared with horizon-prepare from
      your own legally obtained copy of Minecraft. Not an official Minecraft
      product; not approved by or associated with Mojang or Microsoft.
    '';
    homepage = "https://playhorizon.dev";
    changelog = "https://github.com/horizon-rust/horizon/releases";
    license = lib.licenses.mit;
    mainProgram = if headless then "horizon-server" else "horizon-client";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
