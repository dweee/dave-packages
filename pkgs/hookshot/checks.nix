{ hookshot, runCommand }:
runCommand "hookshot-prerequisites" { } ''
  export HOME=$TMPDIR
  ${hookshot}/libexec/hookshot/python -I -c "import sys; sys.path.insert(0, '${hookshot}/share/hookshot/nx2'); import make_game; make_game.check_linux_prerequisites()" > "$TMPDIR/log" 2>&1
  grep -q "Linux build prerequisites: OK" "$TMPDIR/log"
  if HOOKSHOT_GAME_DIR=$TMPDIR/none ${hookshot}/bin/hookshot 2>"$TMPDIR/err"; then
    exit 1
  fi
  grep -q "no built game" "$TMPDIR/err"
  touch "$out"
''
