# Upstream release binaries include all sources; nixpkgs' default build does not.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  pipewire,
  alsa-lib,
  openssl,
  makeWrapper,
  yt-dlp,
  ffmpeg,
}: let
  isLinux = stdenv.hostPlatform.isLinux;
  source =
    if isLinux
    then {
      url = "https://github.com/LargeModGames/spotatui/releases/download/v0.43.0/spotatui-linux-x86_64.tar.gz";
      hash = "sha256-kH2d05afie7MMxNFLuixhAiSCxur7UEtffgqSloyh6E=";
    }
    else {
      url = "https://github.com/LargeModGames/spotatui/releases/download/v0.43.0/spotatui-macos-aarch64.tar.gz";
      hash = "sha256-dg9wF2mVN26sPuySpi82MXI0jRPxvwiRwH871CMkzoQ=";
    };
in
  stdenvNoCC.mkDerivation {
    pname = "spotatui";
    version = "0.43.0";
    src = fetchurl source;
    nativeBuildInputs = [makeWrapper] ++ lib.optional isLinux autoPatchelfHook;
    buildInputs = lib.optionals isLinux [pipewire alsa-lib openssl stdenv.cc.cc.lib];
    sourceRoot = ".";
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 spotatui $out/bin/spotatui
      wrapProgram $out/bin/spotatui --prefix PATH : ${lib.makeBinPath [yt-dlp ffmpeg]}
      runHook postInstall
    '';
    meta = {
      description = "Terminal player with synced lyrics and Spotify, local, YouTube and Qobuz sources";
      homepage = "https://github.com/LargeModGames/spotatui";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-darwin"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "spotatui";
    };
  }
