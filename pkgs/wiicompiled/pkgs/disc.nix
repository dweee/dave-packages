{
  lib,
  stdenv,
  iso,
  discExtractor,
}:
let
  pins = import ./pal-rmcp01.nix;
in
assert lib.assertMsg (discExtractor != null) "Provide your own Wii disc extractor as discExtractor (nodtool-compatible).";
stdenv.mkDerivation {
  pname = "wiicompiled-disc";
  version = "rmcp01";

  inherit iso;
  dontUnpack = true;

  nativeBuildInputs = [ discExtractor ];

  # Extract where the user-supplied ISO is already available.
  preferLocalBuild = true;
  allowSubstitutes = false;

  buildPhase = ''
    runHook preBuild
    ${discExtractor}/bin/nodtool extract "$iso" DATA -q
    dol=DATA/sys/main.dol
    rel=DATA/files/rel/StaticR.rel
    test -f "$dol" && test -f "$rel"
    dol_sha=$(sha256sum "$dol" | awk '{print $1}')
    rel_sha=$(sha256sum "$rel" | awk '{print $1}')
    if [ "$dol_sha" != ${pins.expectedDol} ] || [ "$rel_sha" != ${pins.expectedRel} ]; then
      echo "Disc did not match PAL RMCP01 pins in projects/mkwii/recomp.yml" >&2
      echo "main.dol    got $dol_sha expected ${pins.expectedDol}" >&2
      echo "StaticR.rel got $rel_sha expected ${pins.expectedRel}" >&2
      exit 1
    fi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a DATA $out/DATA
    cp -a DATA/sys/main.dol $out/main.dol
    cp -a DATA/files/rel/StaticR.rel $out/StaticR.rel
    runHook postInstall
  '';

  meta = {
    description = "Extracted PAL RMCP01 disc files for WiiCompiled";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
  };
}
