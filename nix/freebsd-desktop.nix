# FreeBSD support kept separate from the catalog's default Linux/Darwin overlay.
final: prev:
let
  inherit (prev) lib;
  addFreeBSD = old: {
    meta = old.meta // {
      platforms = old.meta.platforms ++ lib.platforms.freebsd;
    };
  };
in
lib.optionalAttrs prev.stdenv.hostPlatform.isFreeBSD {
  unix-selfauth-helper = final.callPackage ../pkgs/unix-selfauth-helper/package.nix { };
  # libei 1.6 already contains the BSD LOCAL_PEERCRED implementation.
  # Reapplying the old backport duplicates its macros and fails its second hunk.
  libei = prev.libei.overrideAttrs (old: {
    patches = lib.filter (patch: !(lib.hasSuffix "-peercred-bsd.patch" (toString patch))) (
      old.patches or [ ]
    );
  });
  # AML has an upstream kqueue backend. The software desktop needs ordinary
  # VNC encodings, not the optional Linux-oriented FFmpeg/V4L2 H.264 path.
  aml = prev.aml.overrideAttrs addFreeBSD;
  neatvnc = prev.neatvnc.overrideAttrs (
    old:
    (addFreeBSD old)
    // {
      # FreeBSD ships threads.h with libstdthreads, separately from libc.
      buildInputs = (lib.filter (dep: !(lib.hasPrefix "ffmpeg" (lib.getName dep))) old.buildInputs) ++ [
        final.freebsd.libstdthreads
      ];
      mesonFlags = old.mesonFlags ++ [ "-Dh264=disabled" ];
    }
  );
  wayvnc = prev.wayvnc.overrideAttrs (
    old:
    (addFreeBSD old)
    // {
      buildInputs = old.buildInputs ++ [ final.evdev-proto ];
      # Use libc's fortified strlcpy rather than redefining it with the bundled
      # fallback (which collides with FreeBSD's function-like SSP macro).
      postPatch = (old.postPatch or "") + ''
        substituteInPlace meson.build --replace-fail "'src/strlcpy.c'," ""
        substituteInPlace include/strlcpy.h \
          --replace-fail 'size_t strlcpy(char *dst, const char *src, size_t siz);' '#include <string.h>'
      '';
    }
  );
  # Lua's FreeBSD make target overrides the cross compiler with bare cc and
  # assumes a base-system libedit installation. Use the declared readline
  # dependency and preserve the target compiler passed by stdenv.
  lua5_4 = prev.lua5_4.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/Makefile \
        --replace-fail 'CC="cc"' 'CC="$(CC)"' \
        --replace-fail '-I/usr/include/edit' "" \
        --replace-fail '-ledit' '-lreadline'
    '';
  });
  # 4.1.1 renamed the conflicting _assert symbol to lerc_assert upstream.
  # The old ports patch now reverses that fix and no longer applies.
  lerc = prev.lerc.overrideAttrs (old: {
    patches = lib.filter (patch: !(lib.hasSuffix "-patch-_assert" (toString patch))) (
      old.patches or [ ]
    );
  });
  fcft = prev.fcft.overrideAttrs (
    old:
    (addFreeBSD old)
    // {
      buildInputs = old.buildInputs ++ [ final.freebsd.libstdthreads ];
    }
  );
  # The upstream source already implements the FreeBSD backend. Supply its
  # kqueue-backed epoll compatibility library instead of Linux headers/APIs.
  foot = prev.foot.overrideAttrs (
    old:
    (addFreeBSD old)
    // {
      buildInputs = old.buildInputs ++ [
        final.epoll-shim
        final.evdev-proto
        final.freebsd.libstdthreads
      ];
      mesonFlags = lib.filter (flag: !(lib.hasPrefix "-Dsystemd-units-dir=" flag)) old.mesonFlags;
    }
  );
  swayidle = (prev.swayidle.override { systemdSupport = false; }).overrideAttrs addFreeBSD;
  swaylock = prev.swaylock.overrideAttrs addFreeBSD;
  # The generic recipe currently enables Linux-only drivers and dependencies.
  # Keep a small, explicitly software-only EGL/GLES implementation for BSD VMs.
  mesa = final.callPackage ../pkgs/mesa-freebsd/package.nix { upstreamMesa = prev.mesa; };
}
