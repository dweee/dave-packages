#!/usr/bin/env bash
# horizon-prepare writes its scratch files and, by default, the prepared
# resources under <root>/.local, and the release folder is read-only in the
# Nix store. Without --root, prepare in a writable copy of the folder's
# sources (HORIZON_PREPARE_ROOT, else $XDG_DATA_HOME/horizon/prepare).
set -euo pipefail

folder=$HORIZON_PREPARE_FOLDER
for arg in "$@"; do
  case $arg in
    --root | --root=*) exec "$folder/horizon-prepare" "$@" ;;
  esac
done

root=${HORIZON_PREPARE_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/horizon/prepare}
if [[ "$(cat "$root/.nix-folder" 2>/dev/null || true)" != "$folder" ]]; then
  mkdir -p "$root"
  for path in tools mods crates research-lock.json LICENSE exporters; do
    rm -rf "${root:?}/$path"
    if [[ -e "$folder/$path" ]]; then
      cp -R "$folder/$path" "$root/$path"
      chmod -R u+w "$root/$path"
    fi
  done
  printf '%s\n' "$folder" >"$root/.nix-folder"
fi

# A leading subcommand (sounds, compile-exporters...) must stay first.
exec "$folder/horizon-prepare" "$@" --root "$root"
