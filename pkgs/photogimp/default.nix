{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
# Diolinux PhotoGIMP profile tree (GIMP 3.0 layout).
# Consumed as: photogimp + "/.var/app/org.gimp.GIMP/config/GIMP/3.0"
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "photogimp";
  version = "3.1";

  src = fetchFromGitHub {
    owner = "Diolinux";
    repo = "PhotoGIMP";
    rev = finalAttrs.version;
    hash = "sha256-524lsDRmahWXXP9/cfk2ia+7K6xNFTdoYXO8UUsLP/o=";
  };

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a . $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Photoshop-oriented GIMP profile (PhotoGIMP)";
    homepage = "https://github.com/Diolinux/PhotoGIMP";
    license = licenses.gpl3Plus;
  };
})
