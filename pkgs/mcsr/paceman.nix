{
  pkgs,
  lib,
}:
pkgs.stdenv.mkDerivation rec {
  pname = "paceman-tracker";
  version = "0.7.3";

  src = pkgs.fetchurl {
    url = "https://github.com/PaceMan-MCSR/PaceMan-Tracker/releases/download/v${version}/paceman-tracker-${version}.jar";
    hash = "sha256-djrWOxfqtDJjbCJ7vQBfwQh4rU9Vnv25NEmVd7wtPRo=";
  };
  dontUnpack = true;

  nativeBuildInputs = [pkgs.copyDesktopItems pkgs.makeWrapper];

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "paceman-tracker";
      type = "Application";
      exec = "paceman-tracker";
      comment = "A standalone application or Julti plugin to track and upload runs to PaceMan.gg.";
      desktopName = "PaceMan Tracker";
      genericName = "An application to track and upload runs";
      categories = ["Game"];
    })
  ];

  installPhase = ''
    install -m 644 -D $src "$out/share/paceman/paceman-tracker-${version}.jar"

    makeWrapper ${pkgs.jre}/bin/java $out/bin/paceman-tracker \
      --add-flags "-jar $out/share/paceman/paceman-tracker-${version}.jar"
  '';

  meta = {
    description = "A standalone application to track and upload runs to PaceMan.gg";
    homepage = "https://github.com/PaceMan-MCSR/PaceMan-Tracker";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [lib.sourceTypes.binaryBytecode];
  };
}
