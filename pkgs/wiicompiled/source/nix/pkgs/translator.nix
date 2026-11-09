{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  src,
}:
buildDotnetModule {
  pname = "wiicompiled-translator";
  version = "0.5.0";
  inherit src;

  projectFile = "translator/src/Translator.Cli/Translator.Cli.csproj";
  nugetDeps = ./nuget-deps.nix;
  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;
  executables = ["Translator.Cli"];

  # .NET 8.0.32+ named mutexes require writable runtime state even before
  # restore. Nix build users' passwd homes are not writable; HOME alone does
  # not redirect this lookup. Match the Setup build's per-build isolation.
  postUnpack = ''
    export XDG_RUNTIME_DIR="$NIX_BUILD_TOP/dotnet-runtime"
    mkdir -m 700 "$XDG_RUNTIME_DIR"
  '';

  meta = {
    description = "WiiCompiled PowerPC-to-C++ translator";
    homepage = "https://github.com/patchzyy/Wiicompiled";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "Translator.Cli";
  };
}
