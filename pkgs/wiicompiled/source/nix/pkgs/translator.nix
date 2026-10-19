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

  meta = {
    description = "WiiCompiled PowerPC-to-C++ translator";
    homepage = "https://github.com/patchzyy/Wiicompiled";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "Translator.Cli";
  };
}
