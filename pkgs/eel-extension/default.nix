{
  fetchFromGitHub,
  vscode-utils,
  lib,
  buildNpmPackage,
  nodejs,
  vsce,
  stdenv,
}: let
  # Values from the user's snippet
  vscodeExtPublisher = "eclairevoyant";
  vscodeExtName = "eel";
  version = "unstable-20251114";
  src = fetchFromGitHub {
    owner = "Faupi";
    repo = "eel";
    rev = "7d67183632f99bab981a64ab42c2aeb9d106b7aa";
    hash = "sha256-szm8mKTw2RF1zOW5uAn1ccycveJDDWToGRu31ESfBl8=";
  };

  utilitiesDeps = buildNpmPackage {
    pname = "utilities";
    inherit version;
    src = "${src}/utilities";
    npmDepsHash = "sha256-E89XJEQl4YDknL99cGWrNxFjFnbKPVPnovOJy8LWkdk=";

    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # The extension derivation for use in Nix/VSCode
  extension = vscode-utils.buildVscodeExtension {
    inherit vscodeExtPublisher vscodeExtName src version;
    vscodeExtUniqueId = "${vscodeExtPublisher}.${vscodeExtName}";
    pname = "${vscodeExtPublisher}.${vscodeExtName}";

    nativeBuildInputs = [
      nodejs
    ];

    buildPhase = ''
      runHook preBuild

      ln -s ${utilitiesDeps}/node_modules ./node_modules
      make syntax

      runHook postBuild
    '';

    sourceRoot = "source";
  };
in
  stdenv.mkDerivation {
    pname = "${vscodeExtPublisher}-${vscodeExtName}-vsix";
    inherit version src;

    nativeBuildInputs = [
      nodejs
      vsce
    ];

    sourceRoot = "source";

    buildPhase = ''
      runHook preBuild

      ln -s ${utilitiesDeps}/node_modules ./node_modules
      make syntax
      vsce package --no-git-tag-version --no-update-package-json --no-dependencies -o extension.vsix

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p $out
      cp extension.vsix $out/${vscodeExtPublisher}.${vscodeExtName}-${version}.vsix
    '';

    passthru = {
      inherit extension;
    };

    meta = with lib; {
      description = "EEL extension for VS Code";
      homepage = "https://github.com/Faupi/eel";
      license = licenses.mit;
      maintainers = [];
    };
  }
