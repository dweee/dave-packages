{ final, root }:
let
  inherit (final) lib;
  sources = import ./sources.nix { inherit lib root; };
in
{
  wiicompiled-nodtool = final.callPackage ./nodtool.nix { };
  wiicompiled-translator = final.callPackage ./translator.nix { src = sources.translator; };
  wiicompiled-native-prebuilt = final.callPackage ./native-prebuilt.nix {
    src = sources.nativePrebuilt;
  };
  wiicompiled-setup =
    if final.stdenv.hostPlatform.isDarwin then
      final.callPackage ./setup-macos.nix { src = sources.setup; }
    else
      final.callPackage ./setup.nix { src = sources.setup; };
}
