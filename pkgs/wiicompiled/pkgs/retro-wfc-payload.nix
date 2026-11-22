{
  lib,
  payload,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "wiicompiled-retro-wfc-payload";
  version = "0.1.1-2026-08-06";

  # The user supplies the payload file. Keep it and the derived blob local.
  preferLocalBuild = true;
  allowSubstitutes = false;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/binary
    cp ${lib.escapeShellArg (toString payload)} $out/binary/payload.RMCPD00.bin
    payload=$out/binary/payload.RMCPD00.bin
    magic=$(dd if="$payload" bs=12 count=1 status=none)
    if [ "$magic" != "WWFC/Payload" ]; then
      echo "Retro-WFC payload magic is not WWFC/Payload" >&2
      exit 1
    fi
    if ! grep -a -q RMCPD00 "$payload"; then
      echo "Retro-WFC payload is not the RMCPD00 (PAL) blob" >&2
      exit 1
    fi
    runHook postInstall
  '';

  meta = {
    description = "Pinned Retro-WFC RMCPD00 payload for WiiCompiled Retro Rewind";
    homepage = "https://github.com/Retro-Rewind-Team/wfc-patcher-wii";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
