{ final, root }:
let
  inherit (final) lib;
  sources = import ./sources.nix { inherit lib root; };
  launcherProps = builtins.readFile (root + "/Launcher/Directory.Build.props");
  versionMatch = builtins.match ".*<Version>([^<[:space:]]+)</Version>.*" launcherProps;
  version =
    if versionMatch == null
    then throw "WiiCompiled Launcher/Directory.Build.props is missing the product version"
    else builtins.head versionMatch;
in
{
  wiicompiled = final.callPackage
    (if final.stdenv.hostPlatform.isDarwin then ./pkgs/game-macos.nix else ./pkgs/game.nix)
    {
      src = sources.game;
      translateSrc = sources.translate;
      patches = [ ./portable-baseline.patch ];
      packageVersion = final.wiicompiled-setup.version;
    };
  wiicompiled-translator = final.callPackage ./translator.nix { src = sources.translator; };
  wiicompiled-native-prebuilt = final.callPackage ./native-prebuilt.nix {
    src = sources.nativePrebuilt;
  };
  wiicompiled-setup =
    if final.stdenv.hostPlatform.isDarwin then
      final.callPackage ./setup-macos.nix { src = sources.setup; inherit version; }
    else
      final.callPackage ./setup.nix { src = sources.setup; inherit version; };
}
