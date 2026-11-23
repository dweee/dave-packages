#!/bin/sh
# nx2/make_game.py from the Nix package. Without --out, --update or --check the game goes to $HOOKSHOT_GAME_DIR
# (set by the Home Manager module) or ~/Games/Hookshot. With HOOKSHOT_DUMP set (the module's `dump`) and no game
# given, that copy is used: a .nup file, or a folder with romfs/ and exefs/ in it.
#
# The game folder, the build files (~/.cache/hookshot-builder) and everything else made from the game stay in your
# home. Never copy them into the Nix store or share them.
set -eu
make_game=@makeGame@

has_out=
has_game=
for arg in "$@"; do
    case $arg in
        --update|--update=*) has_out=1 has_game=1 ;;
        --out|--out=*) has_out=1 ;;
        --nup|--nup=*|--romfs|--romfs=*|--exefs|--exefs=*|--game|--game=*) has_game=1 ;;
    esac
done

if [ -z "$has_game" ] && [ -n "${HOOKSHOT_DUMP:-}" ]; then
    set -- --game "$HOOKSHOT_DUMP" "$@"
fi
if [ -z "$has_out" ]; then
    set -- "$@" --out "${HOOKSHOT_GAME_DIR:-$HOME/Games/Hookshot}"
fi
if [ -n "${HOOKSHOT_LANGUAGE:-}" ]; then
    case " $* " in
        *" --language "*|*" --language="*) ;;
        *) set -- "$@" --language "$HOOKSHOT_LANGUAGE" ;;
    esac
fi
exec "$make_game" "$@"
