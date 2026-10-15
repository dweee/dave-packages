{
  pkgs,
  lib,
}:
pkgs.stdenv.mkDerivation rec {
  pname = "modcheck";
  version = "3.1.1";

  src = pkgs.fetchurl {
    url = "https://github.com/tildejustin/modcheck/releases/download/${version}/modcheck-${version}.jar";
    hash = "sha256-qAMZmoW74ExQls47GE2biiibTvHyKsOpXOJWu41q10k=";
  };
  dontUnpack = true;

  nativeBuildInputs = [pkgs.copyDesktopItems pkgs.makeWrapper];

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "modcheck";
      type = "Application";
      exec = "modcheck";
      comment = "Minecraft SpeedRun Mods Auto Installer/Updater";
      desktopName = "ModCheck";
      genericName = "Minecraft SpeedRun Mods Auto Installer/Updater";
      categories = ["Game"];
    })
  ];

  installPhase = ''
    install -m 644 -D $src "$out/share/modcheck/modcheck-${version}.jar"

    makeWrapper ${pkgs.jre}/bin/java $out/bin/modcheck \
      --add-flags "-jar $out/share/modcheck/modcheck-${version}.jar"
  '';

  meta = {
    description = "Minecraft SpeedRun Mods Auto Installer/Updater";
    homepage = "https://github.com/tildejustin/modcheck";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [lib.sourceTypes.binaryBytecode];
  };
}
