{
  lib,
  pkgs,
  cfg,
}:
let
  absolute = lib.types.addCheck lib.types.str (
    value: lib.hasPrefix "/" value && !lib.hasInfix "\n" value
  );
in
{
  enable = lib.mkEnableOption "Patchbay Mod Loader (BML), the Bitwig Studio mod loader";

  package = lib.mkPackageOption pkgs "patchbay" { default = null; };

  java = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    example = lib.literalExpression "pkgs.jdk25";
    description = ''
      Java runtime used for the Patchbay window and the preparer, exported as
      `BML_JAVA` (its `bin/java`). Null leaves `BML_JAVA` unset, so the
      wrappers fall back to the JDK the package was built with.
    '';
  };

  bitwigPackage = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    example = lib.literalExpression "pkgs.bitwig-studio-latest";
    description = ''
      Bitwig Studio package (Linux) to install and to use as Patchbay's default
      Bitwig: `<package>/bin/bitwig-studio` is exported as
      `BML_BITWIG_EXECUTABLE` and is what Patchbay starts while no other
      Bitwig is chosen in Settings (a `bitwig.executable` already saved in
      `bml.properties` wins). Bitwig's own files are read from `bitwigHome`.
      Bitwig is not a dependency of this flake: pass one from the flake that
      provides it, e.g. `pkgs.bitwig-studio-latest` from audio.nix's overlay.
      Null leaves Patchbay's default, `/opt/bitwig-studio/bitwig-studio`.
    '';
  };

  bitwigApp = lib.mkOption {
    type = lib.types.nullOr absolute;
    default = null;
    example = "/Applications/Bitwig Studio.app";
    description = ''
      Absolute path to a Bitwig Studio installed outside Nix, for macOS where
      Bitwig is not a Nix package: the `.app` bundle (its
      `Contents/MacOS/BitwigStudio` is used) or the executable itself.
      Exported as `BML_BITWIG_EXECUTABLE`. Nothing is installed. Mutually
      exclusive with `bitwigPackage`. Null leaves Patchbay's default,
      `/Applications/Bitwig Studio.app`.
    '';
  };

  bitwigHome = lib.mkOption {
    type = lib.types.nullOr absolute;
    default =
      if cfg.bitwigPackage != null then
        "${pkgs.callPackage ../bitwig-home.nix { } cfg.bitwigPackage}"
      else
        null;
    defaultText = lib.literalMD ''
      with `bitwigPackage`, a link (built with it) to the install folder in
      it: `libexec` of the package or of its `passthru.unwrapped`, else the
      folder `bin/bitwig-studio-unwrapped` or `bin/bitwig-studio` links to;
      else `null`
    '';
    example = lib.literalExpression ''"''${pkgs.bitwig-studio6-1-unwrapped}/libexec"'';
    description = ''
      Bitwig's install folder, the one holding `bin/bitwig.jar` and `lib/jre`
      (on macOS the `.app`), exported as `BML_BITWIG_HOME`. Patchbay reads
      Bitwig's jars and Java runtime there while it uses the default Bitwig
      (`BML_BITWIG_EXECUTABLE`), and still starts that executable: a wrapper
      such as audio.nix's bubblewrap one keeps its sandbox. Needed when the
      executable is not inside the install folder; set it by hand when it
      cannot be found in `bitwigPackage`. Null: Bitwig's files are beside
      the file the executable links to.
    '';
  };
}
