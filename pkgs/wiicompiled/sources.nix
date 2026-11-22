# Layer-specific source trees keep unrelated upstream changes out of build inputs.
{
  lib,
  root,
}:
let
  fs = lib.fileset;
  toSource =
    fileset:
    fs.toSource {
      inherit root fileset;
    };
in
{
  translator = toSource (
    fs.unions [
      (root + "/translator/src")
      (root + "/Launcher/WiiCompiled.Setup.Common")
    ]
  );

  # Aurora + Crypto++ + the runtime CMake that harvests them. Product assets,
  # generated C++, and the translator are intentionally absent.
  nativePrebuilt = toSource (
    fs.unions [
      (root + "/aurora-main")
      (root + "/runtime/CMakeLists.txt")
      (root + "/runtime/cmake")
      (root + "/runtime/include")
      (root + "/runtime/src")
      (root + "/runtime/tests")
      (root + "/runtime/third_party")
    ]
  );

  setup = toSource (
    fs.unions [
      (root + "/runtime")
      (root + "/aurora-main")
      (root + "/projects")
      (root + "/Launcher")
    ]
  );
}
