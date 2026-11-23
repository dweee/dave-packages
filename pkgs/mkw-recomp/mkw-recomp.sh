#!/bin/sh
# The Nix package's entry (nix/package.nix), as the AppImage's AppRun (tools/build/release.py APPRUN): the runtime runs
# from a copy in the player's data folder, which holds the game the setup builds, its settings and caches; setup/
# stays in the read-only store. MKW_RECOMP_HOME moves that folder (the Home Manager module's dataDir).
set -eu
here=@share@
home=${MKW_RECOMP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/mkw-recomp}
export PATH="@path@${PATH:+:$PATH}"
mkdir -p "$home"
if ! cmp -s "$here/mkw" "$home/mkw"; then
    # a rename, not a write over it: a mkw still running keeps its old file
    cp "$here/mkw" "$home/mkw.new"
    chmod u+w "$home/mkw.new"
    mv -f "$home/mkw.new" "$home/mkw"
fi
ln -sfn "$here/setup" "$home/setup"
# libdbus: runtime/input/linux_switch2.c dlopens it for the controllers over Bluetooth (BlueZ)
export LD_LIBRARY_PATH="@libs@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# NVIDIA's nvdisasm and ptxas, patched for Nix (nix/nvidia-tools.nix); empty: spec.py downloads them
nvidia=@nvidia@
if [ -n "$nvidia" ] && [ -z "${MKW_NVIDIA_BIN:-}" ]; then
    export MKW_NVIDIA_BIN="$nvidia"
fi
exec "$home/mkw" "$@"
