# Linux CLI from steipete/CodexBar release tarballs. nixpkgs#codexbar is the
# Darwin menu-bar app only. The psimaker Plasma widget shells out to `codexbar`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  curl,
  libxml2,
  sqlite,
}: let
  pname = "codexbar-cli";
  version = "0.67.0";

  assets = {
    x86_64-linux = {
      name = "CodexBarCLI-v${version}-linux-x86_64.tar.gz";
      hash = "sha256-Me0fpKUO6N9uZIPPcE6il7X4WGLN8eUkM2NmzetSHrM=";
    };
    aarch64-linux = {
      name = "CodexBarCLI-v${version}-linux-aarch64.tar.gz";
      hash = "sha256-5fkcGO9e1S1yzCLLgtPsfGiNGKJSo6IFSSAG2pIpKC8=";
    };
  };

  asset =
    assets.${stdenv.hostPlatform.system}
    or (throw "${pname} is only packaged for x86_64-linux and aarch64-linux");
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/steipete/CodexBar/releases/download/v${version}/${asset.name}";
      inherit (asset) hash;
    };

    sourceRoot = ".";

    nativeBuildInputs = [autoPatchelfHook];

    buildInputs = map lib.getLib [curl libxml2 sqlite] ++ [stdenv.cc.cc.lib];

    # Plugin scripts and VERSION sit beside the executable. Swift resolves
    # /proc/self/exe through the bin symlink, so the real files live in libexec.
    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec/codexbar $out/bin
      cp -a CodexBarCLI codexbar VERSION CodexBar_CodexBarCore.bundle $out/libexec/codexbar/
      chmod 755 $out/libexec/codexbar/CodexBarCLI $out/libexec/codexbar/codexbar
      ln -s $out/libexec/codexbar/codexbar $out/bin/codexbar
      ln -s $out/libexec/codexbar/CodexBarCLI $out/bin/CodexBarCLI
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/codexbar --help >/dev/null
      # Loads the provider bundle. No credentials, so usage itself may fail;
      # a missing bundle is a packaging bug.
      if $out/bin/codexbar usage --format json --json-only --provider openai 2>&1 | grep -q 'no bundled provider plugin'; then
        echo "codexbar-cli: provider plugin bundle was not found beside the executable" >&2
        exit 1
      fi
    '';

    meta = {
      description = "CLI for AI coding-provider usage limits";
      homepage = "https://github.com/steipete/CodexBar";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "codexbar";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    };
  }
