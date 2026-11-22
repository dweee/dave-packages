#!@shell@
# Runs one of BML's sh scripts from a writable copy of the packaged loader root.
#   bml-root <script in the root, e.g. bml-ui.sh> [arguments]
# The package's root (@share@) is read-only, and BML writes into its root at runtime (mods/, maps/,
# config/, state/, sessions/, loader/mod-runtime/, the agent's session files and reports). So the
# root is ${BML_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/bml}: every file of the package's root is
# copied there (made writable) when the package changes, which <root>/.nix-store-path records; a
# file the previous package had and this one has not is removed. Nothing else in the root is
# touched. One sync runs at a time (<root>/.nix-store-lock); a root that holds something else than
# BML is refused.
set -eu
STORE=@share@
SCRIPT=$1
shift
case "${XDG_DATA_HOME:-}" in /*) DATA=$XDG_DATA_HOME ;; *) DATA=$HOME/.local/share ;; esac
ROOT=${BML_ROOT:-$DATA/bml}
case "$ROOT" in
  /*) ;;
  *) echo "patchbay: BML_ROOT must be an absolute path, not $ROOT" >&2; exit 2 ;;
esac
MARK=$ROOT/.nix-store-path
LIST=$ROOT/.nix-store-files
LOCK=$ROOT/.nix-store-lock

# What BML (or the user, or home-manager's programs.patchbay) writes into the root: never copied
# over or removed.
user_data() {
  case "$1" in
    mods|mods/*|maps|maps/*|config|config/*|state|state/*|sessions|sessions/*|components|components/*) return 0 ;;
    loader/mod-runtime|loader/mod-runtime/*|loader/jvmti/bin/session.conf|loader/jvmti/active-session.txt) return 0 ;;
    loader/jvmti/reports|loader/jvmti/reports/*) return 0 ;;
    .nix-store-*|.hm-*) return 0 ;;
  esac
  return 1
}
# Shipped as a starting point the user edits: copied only when missing, never removed.
seed() {
  case "$1" in loader/diagnostics/trace-targets.tsv) return 0 ;; esac
  return 1
}

NEW=
LOCKED=
cleanup() {
  if [ -n "$NEW" ]; then rm -f -- "$NEW"; fi
  if [ -n "$LOCKED" ]; then rm -rf -- "$LOCK"; fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

synced() { [ "$(cat "$MARK" 2>/dev/null || true)" = "$STORE" ]; }

if ! synced; then
  mkdir -p "$ROOT"
  # Wait up to a minute for another sync; a lock whose process is gone is taken over.
  n=0
  until mkdir "$LOCK" 2>/dev/null; do
    pid=$(cat "$LOCK/pid" 2>/dev/null || true)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      rm -rf -- "$LOCK"
      continue
    fi
    n=$((n + 1))
    if [ "$n" -gt 600 ]; then
      echo "patchbay: $LOCK is held by another sync (process ${pid:-unknown}); remove it if none runs." >&2
      exit 1
    fi
    sleep 0.1
  done
  LOCKED=1
  echo $$ >"$LOCK/pid"
fi

if ! synced; then
  if [ ! -f "$MARK" ] && [ ! -f "$ROOT/loader/app/bml-control.jar" ]; then
    for entry in "$ROOT"/* "$ROOT"/.[!.]* "$ROOT"/..?*; do
      if [ -e "$entry" ] || [ -L "$entry" ]; then
        if ! user_data "${entry##*/}"; then
          echo "patchbay: $ROOT holds files that are not BML's (${entry##*/}); set BML_ROOT to an empty folder or a BML folder." >&2
          exit 2
        fi
      fi
    done
  fi
  NEW=$(mktemp "$ROOT/.nix-store-files.XXXXXX")
  (cd "$STORE" && find . ! -type d) | sed 's|^\./||' | LC_ALL=C sort >"$NEW"
  if [ -f "$LIST" ]; then
    LC_ALL=C sort "$LIST" | LC_ALL=C comm -23 - "$NEW" | while IFS= read -r f; do
      if ! user_data "$f" && ! seed "$f"; then rm -f -- "$ROOT/$f"; fi
    done
  fi
  (cd "$STORE" && find . -type d) | sed 's|^\./||' | while IFS= read -r d; do
    if [ "$d" != . ] && ! user_data "$d"; then mkdir -p -- "$ROOT/$d" && chmod u+w -- "$ROOT/$d"; fi
  done
  while IFS= read -r f; do
    if seed "$f"; then
      if [ ! -e "$ROOT/$f" ] && [ ! -L "$ROOT/$f" ]; then
        cp -- "$STORE/$f" "$ROOT/$f"
        chmod u+w -- "$ROOT/$f"
      fi
    elif ! user_data "$f"; then
      rm -f -- "$ROOT/$f"
      cp -- "$STORE/$f" "$ROOT/$f"
      chmod u+w -- "$ROOT/$f"
    fi
  done <"$NEW"
  mv -f -- "$NEW" "$LIST"
  NEW=
  printf '%s\n' "$STORE" >"$MARK.new"
  mv -f -- "$MARK.new" "$MARK"
fi
cleanup
trap - EXIT HUP INT TERM
exec "$ROOT/$SCRIPT" "$@"
