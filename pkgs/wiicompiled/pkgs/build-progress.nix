# Nix sandboxes have no TTY, so Ninja's [n/m] bar is off and it only prints when
# a command exits. Hour-long translated shards look hung. These wrappers print
# when a compile/link starts and a heartbeat while cmake --build is still alive.
{ writeShellScript }: rec {
  announceCompile = writeShellScript "wiicompiled-announce-compile" ''
    set -eu
    src=
    out=
    prev=
    for a in "$@"; do
      case "$a" in
        *.cpp|*.cc|*.cxx|*.c|*.m|*.mm|*.S|*.s) src=$a ;;
      esac
      if [ "$prev" = "-o" ]; then
        out=$a
      fi
      prev=$a
    done
    ts=$(date '+%H:%M:%S')
    if [ -n "''${src:-}" ]; then
      echo "compile start $ts ''${src##*/}" >&2
    elif [ -n "''${out:-}" ]; then
      echo "link start $ts ''${out##*/}" >&2
    else
      echo "tool start $ts $1" >&2
    fi
    exec "$@"
  '';

  cmakeBuild = writeShellScript "wiicompiled-cmake-build-progress" ''
    set -eu
    cmake --build "$@" &
    pid=$!
    (
      while kill -0 "$pid" 2>/dev/null; do
        sleep 60
        if kill -0 "$pid" 2>/dev/null; then
          echo "cmake --build still running $(date '+%H:%M:%S')" >&2
        fi
      done
    ) &
    hb=$!
    set +e
    wait "$pid"
    status=$?
    set -e
    kill "$hb" 2>/dev/null || true
    wait "$hb" 2>/dev/null || true
    exit "$status"
  '';

  # Sets compile_launchers for CMAKE_*_COMPILER_LAUNCHER. ccache is used only
  # when the host cache dir is bind-mounted and writable (see ccache-dir.nix).
  launchersHook =
    { ccache }:
    let
      dir = (import ./ccache-dir.nix).path;
    in
    ''
      compile_launchers=${announceCompile}
      if [ -d ${dir} ] && [ -w ${dir} ]; then
        export CCACHE_DIR=${dir}
        export CCACHE_COMPRESS=1
        export CCACHE_UMASK=007
        export CCACHE_NOHASHDIR=1
        export CCACHE_COMPILERCHECK=content
        export CCACHE_MAXSIZE=25G
        compile_launchers="$compile_launchers;${ccache}/bin/ccache"
        echo "ccache enabled at $CCACHE_DIR" >&2
      else
        echo "ccache skipped (sandbox has no ${dir})" >&2
      fi
    '';
}
