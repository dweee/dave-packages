# The launcher in an FHS environment, for Linux.
#
# The launcher downloads Horizon's own prebuilt game builds and starts them
# as its children; they expect /lib64/ld-linux and the usual libraries
# under /usr/lib. Native mods are built by the launcher too, with a Rust
# toolchain it downloads, which needs a C linker and the -sys crates'
# headers and pkg-config files.
{
  lib,
  buildFHSEnv,
  launcher,
  jdk25,
  withNativeModToolchain ? true,
}:

buildFHSEnv {
  pname = "horizon-launcher";
  inherit (launcher) version;

  targetPkgs =
    pkgs:
    [
      launcher
      # The game and its preparation (Java for the vanilla exporters).
      jdk25
    ]
    ++ (with pkgs; [
      alsa-lib
      alsa-plugins
      pipewire
      libpulseaudio
      systemdLibs
      libGL
      vulkan-loader
      wayland
      libxkbcommon
      libx11
      libxcb
      libxcursor
      libxi
      libxrandr
      fontconfig
      freetype
      openssl
      zlib
      xdg-utils
      stdenv.cc.cc.lib
    ])
    ++ lib.optionals withNativeModToolchain (
      with pkgs;
      [
        stdenv.cc
        pkg-config
        alsa-lib.dev
        systemdLibs.dev
        openssl.dev
        gnumake
        git
      ]
    );

  extraOutputsToInstall = lib.optional withNativeModToolchain "dev";

  profile = ''
    export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
    # The menu entry the launcher writes must start this environment, not the
    # bare binary inside it.
    export HORIZON_LAUNCHER_DESKTOP_EXEC=''${HORIZON_LAUNCHER_DESKTOP_EXEC:-horizon-launcher}
    export JAVA_HOME=${jdk25.home}
    export ALSA_PLUGIN_DIR=/usr/lib/alsa-lib
    ${lib.optionalString withNativeModToolchain ''
      export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig
    ''}
  '';

  runScript = "horizon-launcher";

  extraInstallCommands = ''
    mkdir -p $out/share
    if [ -e ${launcher}/share/icons ]; then
      ln -s ${launcher}/share/icons $out/share/icons
    fi
    install -Dm644 -t $out/share/applications ${launcher}/share/applications/horizon-launcher.desktop
  '';

  passthru = {
    unwrapped = launcher;
    inherit (launcher) pin;
  };

  # The launcher's own platforms, on Linux: upstream's build (-bin) has no ARM Linux one.
  meta = launcher.meta // {
    platforms = lib.intersectLists lib.platforms.linux launcher.meta.platforms;
  };
}
