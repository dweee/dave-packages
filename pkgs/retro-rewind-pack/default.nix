{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  writeShellApplication,
  curl,
  nix,
  python3,
}:
let
  pin = lib.importJSON ./pin.json;
  updater = writeShellApplication {
    name = "update-retro-rewind-pack";
    runtimeInputs = [
      curl
      nix
      python3
    ];
    text = ''
      exec python3 ${./update.py} --pin-file pkgs/retro-rewind-pack/pin.json --apply "$@"
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "retro-rewind-pack";
  inherit (pin) version;
  src = fetchurl {
    url = "https://cdn.update.rwfc.net/RetroRewind/zip/${pin.version}-full.zip";
    inherit (pin) hash;
  };
  nativeBuildInputs = [ unzip ];
  preferLocalBuild = true;
  allowSubstitutes = false;
  dontFixup = true;
  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src" -d unpacked
    runHook postUnpack
  '';
  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    mapfile -t candidates < <(find unpacked -type f -path '*/Binaries/Code.pul')
    if [ "''${#candidates[@]}" -ne 1 ]; then
      echo "expected exactly one Binaries/Code.pul" >&2
      exit 1
    fi
    pack=$(dirname "$(dirname "''${candidates[0]}")")
    mkdir -p "$out"
    cp -a "$pack"/. "$out/"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test -s "$out/Binaries/Code.pul"
  '';
  passthru.updateScript.command = [ (lib.getExe updater) ];
  meta = {
    description = "Retro Rewind Riivolution pack (Wheel Wizard full install ZIP)";
    homepage = "https://update.rwfc.net/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
