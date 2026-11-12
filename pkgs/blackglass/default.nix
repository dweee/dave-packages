{
  lib,
  stdenvNoCC,
  fetchgit,
  python3,
  git,
  nix-prefetch-git,
  writeShellApplication,
}:
let
  pin = lib.importJSON ./pin.json;
  updater = writeShellApplication {
    name = "update-blackglass";
    runtimeInputs = [
      python3
      git
      nix-prefetch-git
    ];
    text = ''
      exec python3 ${./update.py} --pin-file pkgs/blackglass/pin.json --apply "$@"
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "blackglass";
  inherit (pin) version;
  src = fetchgit {
    url = "https://www.opencode.net/phob1an/blackglass.git";
    rev = pin.revision;
    inherit (pin) hash;
  };
  dontBuild = true;
  nativeInstallCheckInputs = [ python3 ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/"{plasma/desktoptheme,plasma/look-and-feel,aurorae/themes,Kvantum,color-schemes,sddm/themes,wallpapers}
    cp -a desktoptheme/blackglass "$out/share/plasma/desktoptheme/"
    cp -a look-and-feel/org.magpie.blackglass.desktop "$out/share/plasma/look-and-feel/"
    cp -a themes/blackglass "$out/share/aurorae/themes/"
    cp -a Kvantum/BlackGlass "$out/share/Kvantum/"
    cp BlackGlass.colors "$out/share/color-schemes/"
    cp -a sddm/themes/blackglass "$out/share/sddm/themes/"
    cp -a wallpapers/BlackGlass "$out/share/wallpapers/"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -s "$out/share/color-schemes/BlackGlass.colors"
    test -s "$out/share/Kvantum/BlackGlass/BlackGlass.kvconfig"
    test -s "$out/share/sddm/themes/blackglass/Main.qml"
    python3 - "$out" <<'PY'
    import json, pathlib, sys
    root = pathlib.Path(sys.argv[1]) / 'share'
    for name in ['plasma/desktoptheme/blackglass', 'plasma/look-and-feel/org.magpie.blackglass.desktop', 'aurorae/themes/blackglass', 'wallpapers/BlackGlass']:
        data = json.loads((root / name / 'metadata.json').read_text())
        assert isinstance(data, dict) and data
    assert not list(root.rglob('*.old'))
    PY
    runHook postInstallCheck
  '';
  passthru.updateScript.command = [ (lib.getExe updater) ];
  meta = {
    description = "Optional Black Glass Plasma, Aurorae, Kvantum and SDDM theme assets";
    homepage = "https://www.opencode.net/phob1an/blackglass";
    license = [
      lib.licenses.gpl2Plus
      lib.licenses.gpl3Only
    ];
    platforms = lib.platforms.linux;
  };
}
