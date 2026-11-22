# The install folder in a Bitwig package (the one holding bin/bitwig.jar and lib/jre, or a .app),
# found when this link to it is built, so evaluation never reads the package: its
# passthru.unwrapped's or its own libexec (the layout of audio.nix and nixpkgs), else the folder of
# the file bin/bitwig-studio-unwrapped or bin/bitwig-studio links to (audio.nix's bubblewrap wrapper
# is a copied script beside such a link).
{ lib, runCommand }:
bitwig:
let
  unwrapped = bitwig.passthru.unwrapped or bitwig.unwrapped or null;
  candidates = lib.optionals (unwrapped != null) [ "${unwrapped}/libexec" ] ++ [
    "${bitwig}/libexec"
    "${bitwig}/Applications/Bitwig Studio.app"
    "${bitwig}/bin/bitwig-studio-unwrapped"
    "${bitwig}/bin/bitwig-studio"
  ];
in
runCommand "bitwig-studio-home"
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    for c in ${lib.escapeShellArgs candidates}; do
      if [ -e "$c" ] && [ ! -d "$c" ]; then c=$(dirname -- "$(readlink -f -- "$c")"); fi
      if [ -f "$c/bin/bitwig.jar" ] || [ -f "$c/Contents/Java/bitwig.jar" ]; then
        ln -s "$c" "$out"
        exit 0
      fi
    done
    echo "programs.patchbay: no Bitwig install folder (bin/bitwig.jar) found in ${bitwig};" >&2
    echo "set programs.patchbay.bitwigHome to it." >&2
    exit 1
  ''
