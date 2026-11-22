# FreeBSD server recipes, separate from the catalog default overlay and from
# the desktop overlay. The attribute set is empty on Linux and Darwin.
final: prev:
let
  inherit (prev) lib;
in
lib.optionalAttrs prev.stdenv.hostPlatform.isFreeBSD {
  # 0.19.1 builds with the upstream Go sources. The recipe excludes FreeBSD
  # only through meta.platforms. openssh and rclone stay on PATH: restic looks
  # them up at runtime for the sftp and rclone backends. rclone's cmount links
  # the fuse3 below; this does not add a restic mount/FUSE claim.
  restic = prev.restic.overrideAttrs (old: {
    meta = (old.meta or { }) // {
      platforms = lib.unique ((old.meta.platforms or [ ]) ++ lib.platforms.freebsd);
    };
  });

  # libfuse's FreeBSD objects compile, including mount_bsd.c. The recipe
  # still lists only Linux and deletes a fuse.conf this platform does not
  # install. The udev output has to exist. This makes rclone's cmount link;
  # it is not a test of the FreeBSD FUSE kernel mount.
  fuse3 = prev.fuse3.overrideAttrs (old: {
    meta = (old.meta or { }) // {
      platforms = lib.unique ((old.meta.platforms or [ ]) ++ lib.platforms.freebsd);
    };
    postInstall = ''
      if [[ -e "$out/etc/fuse.conf" ]]; then
        rm -f "$out/etc/fuse.conf"
      fi
      # FreeBSD does not install fusermount or the man pages this recipe
      # expects, but every output path still has to exist.
      mkdir -p "$udev" "$bin" "$man"
      if [[ -d "$out/etc" ]]; then
        mv "$out/etc" "$udev/"
      fi
    '';
  });

  # The FreeBSD devstat collector is upstream CGO (libdevstat, libkvm, libelf).
  # devstat_freebsd.h also includes libgeom.h. Disabling the collector would
  # drop that metric path.
  prometheus-node-exporter = prev.prometheus-node-exporter.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [
      final.freebsd.libgeom
      final.freebsd.libdevstat
      final.freebsd.libkvm
      final.freebsd.libelf
    ];
  });

  # config.h enables NLS on FreeBSD, so the Debian whois sources include
  # libintl.h. The stock mkpasswd recipe does not put gettext on the compile
  # or link line. `buildPhase` is a bare `make`, so makeFlags would not apply.
  mkpasswd = prev.mkpasswd.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ final.gettext ];
    # sha512crypt is compiled only when libxcrypt's header defines
    # XCRYPT_VERSION_NUM. FreeBSD's unistd.h then redefines crypt_data and
    # crypt_r, so hide that BSD block after libxcrypt has been included.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace mkpasswd.c \
        --replace-fail '#include <unistd.h>' $'#include <crypt.h>\n#undef __BSD_VISIBLE\n#define __BSD_VISIBLE 0\n#include <unistd.h>'
    '';
    buildPhase = ''
      runHook preBuild
      make mkpasswd LIBS=-lintl
      runHook postBuild
    '';
  });

  # The stock recipe forces CGO off. On FreeBSD that leaves the runtime
  # without an extra M, so a signal delivered with no Go g aborts:
  # "fatal: bad g in signal handler", before the local API socket exists.
  # GODEBUG=asyncpreemptoff does not avoid it. CGO links libthr and the
  # extra M. The Linux iproute2/iptables wrapper stays Linux-only.
  tailscale = prev.tailscale.overrideAttrs (old: {
    env = (old.env or { }) // {
      CGO_ENABLED = 1;
    };
  });

  # The binary is the same upstream build. Linux systemd units are not a
  # FreeBSD service and are not a runtime dependency.
  caddy = prev.caddy.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm -rf "$out/lib/systemd"
    '';
  });
}
