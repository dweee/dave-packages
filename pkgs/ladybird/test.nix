{
  runCommand,
  ladybird,
  dejavu_fonts,
}:
runCommand "ladybird-sandbox-fontconfig-test"
  {
    nativeBuildInputs = [ ladybird ];
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    export QT_QPA_PLATFORM=offscreen
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    cat > "$TMPDIR/text.html" <<'HTML'
    <!doctype html><meta charset="utf-8">
    <style>body{font:13px "DejaVu Sans";color:black;background:white}</style>
    <p>The quick brown fox jumps over the lazy dog. 0123456789</p>
    <p>Customer must meet and maintain the following security requirements.</p>
    HTML
    for hint in 0 3; do
      cat > "$TMPDIR/fonts-$hint.conf" <<XML
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${dejavu_fonts}/share/fonts/truetype</dir>
      <cachedir>$TMPDIR/font-cache</cachedir>
      <alias><family>sans-serif</family><prefer><family>DejaVu Sans</family></prefer></alias>
      <alias><family>serif</family><prefer><family>DejaVu Serif</family></prefer></alias>
      <alias><family>monospace</family><prefer><family>DejaVu Sans Mono</family></prefer></alias>
      <match target="pattern">
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><int>$hint</int></edit>
      </match>
    </fontconfig>
    XML
      if ! FONTCONFIG_FILE="$TMPDIR/fonts-$hint.conf" \
        timeout 60 Ladybird --temporary-profile --headless \
        --force-cpu-painting --screenshot-delay 1 \
        --screenshot-path "$TMPDIR/hint-$hint.png" \
        "file://$TMPDIR/text.html" > "$TMPDIR/hint-$hint.log" 2>&1; then
        cat "$TMPDIR/hint-$hint.log"
        exit 1
      fi
      if grep -E 'Fontconfig error|Cannot load default config' "$TMPDIR/hint-$hint.log"; then
        cat "$TMPDIR/hint-$hint.log"
        exit 1
      fi
      test -s "$TMPDIR/hint-$hint.png" || { cat "$TMPDIR/hint-$hint.log"; exit 1; }
    done
    # Exercise the compositor, not just font discovery in the browser process:
    # changing the preloaded rules must change rasterized pixels under Landlock.
    if cmp -s "$TMPDIR/hint-0.png" "$TMPDIR/hint-3.png"; then
      echo 'Fontconfig hinting rules did not affect compositor output' >&2
      exit 1
    fi
    mkdir -p "$out"
    cp "$TMPDIR"/hint-*.png "$out/"
  ''
