# What the NixOS, nix-darwin and home-manager modules share: the packages to
# install, the session variables and the assertions for programs.patchbay.
{ lib, cfg }:
let
  # "Bitwig Studio.app" -> its executable; anything else is taken as the executable.
  appExecutable =
    path:
    let
      bundle = lib.removeSuffix "/" path;
    in
    if lib.hasSuffix ".app" bundle then "${bundle}/Contents/MacOS/BitwigStudio" else path;
  bitwigExecutable =
    if cfg.bitwigPackage != null then
      "${cfg.bitwigPackage}/bin/bitwig-studio"
    else if cfg.bitwigApp != null then
      appExecutable cfg.bitwigApp
    else
      null;
in
{
  packages = [ cfg.package ] ++ lib.optional (cfg.bitwigPackage != null) cfg.bitwigPackage;

  variables =
    lib.optionalAttrs (cfg.java != null) { BML_JAVA = lib.getExe' cfg.java "java"; }
    // lib.optionalAttrs (bitwigExecutable != null) { BML_BITWIG_EXECUTABLE = bitwigExecutable; }
    // lib.optionalAttrs (cfg.bitwigHome != null) { BML_BITWIG_HOME = cfg.bitwigHome; };

  assertions = [
    {
      assertion = cfg.bitwigPackage == null || cfg.bitwigApp == null;
      message = "programs.patchbay: set bitwigPackage or bitwigApp, not both.";
    }
  ];
}
