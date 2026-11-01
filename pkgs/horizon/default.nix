# Every Horizon package, in each channel ./sources.json pins (./update.py).
#
#   channels.<stable|unstable|head>.{launcher, game, server}   source builds
#   channels.<stable|unstable>.{game-bin, server-bin}          prebuilt archives
#   launcher-bin, mixins
#
# The flat attributes the catalog exports are listed at the end. The
# launcher has one release line, so its unstable channel is its stable one.
{
  lib,
  stdenv,
  callPackage,
  sources ? lib.importJSON ./sources.json,
}:

let
  linux = stdenv.hostPlatform.isLinux;
  wrapFolder = callPackage ./wrap-folder.nix { };
  mixins = callPackage ./mixins.nix { pin = sources.mixins; };

  # On Linux the launcher runs in an FHS environment (./fhs.nix).
  wrapLauncher = launcher: if linux then callPackage ./fhs.nix { inherit launcher; } else launcher;

  launcher = pin: wrapLauncher (callPackage ./launcher.nix { inherit pin; });
  game =
    pin: headless:
    callPackage ./game.nix {
      inherit pin headless wrapFolder;
      horizon-mixins = mixins;
    };
  bin = kind: pin: callPackage ./bin.nix { inherit kind pin wrapFolder; };

  channel =
    name:
    {
      launcher = launcher sources.launcher.${name} or sources.launcher.stable;
      game = game sources.game.${name} false;
      server = game sources.game.${name} true;
    }
    // lib.optionalAttrs (sources.bin ? ${name}) {
      game-bin = bin "game" sources.bin.${name};
      server-bin = bin "server" sources.bin.${name};
    };

  channels = lib.genAttrs [
    "stable"
    "unstable"
    "head"
  ] channel;
  launcher-bin = wrapLauncher (bin "launcher" sources.bin.launcher);
in
{
  inherit channels launcher-bin;
  inherit mixins;

  # The catalog's attribute names: no suffix for stable, -unstable, -git.
  # The -bin-unstable archives are replaced in place by each Nightly, so they
  # are built only through channels.unstable (the modules), not the catalog CI.
  packages = {
    horizon-launcher = channels.stable.launcher;
    horizon-launcher-git = channels.head.launcher;
    horizon-launcher-bin = launcher-bin;
    horizon = channels.stable.game;
    horizon-unstable = channels.unstable.game;
    horizon-git = channels.head.game;
    horizon-server = channels.stable.server;
    horizon-server-unstable = channels.unstable.server;
    horizon-server-git = channels.head.server;
    horizon-bin = channels.stable.game-bin;
    horizon-bin-unstable = channels.unstable.game-bin;
    horizon-server-bin = channels.stable.server-bin;
    horizon-server-bin-unstable = channels.unstable.server-bin;
    horizon-mixins = mixins;
  };
}
