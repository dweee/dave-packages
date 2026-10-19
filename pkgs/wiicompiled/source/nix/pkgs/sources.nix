# Content-addressed source trees so each layer only rebuilds when its inputs
# change. `root` is this checkout (nix/pkgs/../..), a Nix path so fileset works
# even when flake `self` has already been copied to the store as a string.
{
  lib,
  root ? ../..,
}: let
  fs = lib.fileset;
  toSource = fileset:
    fs.toSource {
      inherit root fileset;
    };
in {
  translator = toSource (fs.unions [
    (root + "/translator/src")
    (root + "/Launcher/WiiCompiled.Setup.Common")
  ]);

  # Aurora + Crypto++ + the runtime CMake that harvests them. Product assets,
  # generated C++, and the translator are intentionally absent.
  nativePrebuilt = toSource (fs.unions [
    (root + "/aurora-main")
    (root + "/runtime/CMakeLists.txt")
    (root + "/runtime/cmake")
    (root + "/runtime/include")
    (root + "/runtime/src")
    (root + "/runtime/tests")
    (root + "/runtime/third_party")
  ]);

  # Translator workspace: PAL pins, MAP, and the native-registration sources
  # emit-build-shards indexes. Aurora and Nix files must not invalidate this.
  translate = toSource (fs.unions [
    (root + "/projects/mkwii")
    (root + "/runtime/src")
  ]);

  # Product compile: runtime + aurora headers/sources (headers are resolved via
  # @AURORA@ tokens) + the macOS .app publisher. local-build.sh is not used.
  game = toSource (fs.unions [
    (root + "/runtime")
    (root + "/aurora-main")
    (root + "/Launcher/macos/publish-app.command")
  ]);

  setup = toSource (fs.unions [
    (root + "/runtime")
    (root + "/aurora-main")
    (root + "/projects")
    (root + "/Launcher")
  ]);
}
