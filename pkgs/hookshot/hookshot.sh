#!/bin/sh
# Start the game hookshot-build made, from its folder: $HOOKSHOT_GAME_DIR (the Home Manager module sets it) or
# ~/Games/Hookshot. Every argument goes to the game (the readme's "Running the game from the command line").
#
# The game was linked with the package's libraries in its RUNPATH; the same ones go on the search path here too, so a
# folder built by an older package still starts while their sonames match. After a flake bump, rebuild the folder:
# hookshot-build --update "$HOOKSHOT_GAME_DIR".
set -eu
dir=${HOOKSHOT_GAME_DIR:-$HOME/Games/Hookshot}

if [ -x "$dir/bin/hookshot" ]; then
    game=$dir/bin/hookshot
elif [ -f "$dir/hookshot" ] && [ -x "$dir/hookshot" ]; then
    game=$dir/hookshot
else
    game=
fi
if [ -z "$game" ] || [ ! -f "$dir/image.bin" ]; then
    echo "Hookshot: no built game in $dir. Build it first: hookshot-build --nup <your-game.nup>" >&2
    exit 1
fi

# (nixpkgs' update path is the flake pin, not the game's release check)
export HOOKSHOT_NO_UPDATE_CHECK=${HOOKSHOT_NO_UPDATE_CHECK:-1}
export LD_LIBRARY_PATH=@runtimeLibPath@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
cd "$dir"
exec "$game" "$@"
