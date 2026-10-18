{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  openssh,
  curl,
}:
# On-TV Node 0.12 agent (tvweb). This package vendors upstream and wraps
# deploy.sh for workstations; it does not run on NixOS.
stdenvNoCC.mkDerivation rec {
  pname = "lg-webos-dashboard";
  version = "0.105.2";

  src = fetchFromGitHub {
    owner = "rorygallagher2024";
    repo = "lg-webos-dashboard";
    rev = "v${version}";
    hash = "sha256-cV7Xnr0rV8QnH/MNxs7kqKdq7kw9ZU9AWGSgufCiJpc=";
  };

  nativeBuildInputs = [makeWrapper];

  # tvwebctl and 50-tvweb.sh run on the TV's BusyBox. stdenv's shebang
  # rewrite would point them at /nix/store/.../bin/sh, which is not there
  # (`tvwebctl: not found`). deploy.sh is invoked via the wrapper below.
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/lg-webos-dashboard
    cp -a . $out/share/lg-webos-dashboard/
    makeWrapper $out/share/lg-webos-dashboard/server/deploy.sh $out/bin/lg-tvweb-deploy \
      --prefix PATH : ${lib.makeBinPath [openssh curl]}
    runHook postInstall
  '';

  meta = {
    description = "On-TV dashboard/MQTT bridge for rooted LG webOS (deploy wrapper)";
    homepage = "https://github.com/rorygallagher2024/lg-webos-dashboard";
    license = lib.licenses.mit;
    mainProgram = "lg-tvweb-deploy";
    platforms = lib.platforms.unix;
  };
}
