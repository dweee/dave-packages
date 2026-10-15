# Matter OTA Provider binary used by python-matter-server for device firmware updates.
# python-matter-server spawns "chip-ota-provider-app" (see matter_server/server/ota/provider.py).
# Home Assistant build: https://github.com/home-assistant-libs/matter-linux-ota-provider
# Pattern from: https://github.com/LongerHV/nixos-configuration (autoPatchelf + libnl)
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libnl,
}: let
  version = "2025.9.0";
  # Release assets: chip-ota-provider-app-x86-64, chip-ota-provider-app-aarch64
  binNames = {
    x86_64-linux = "chip-ota-provider-app-x86-64";
    aarch64-linux = "chip-ota-provider-app-aarch64";
  };
  binName = binNames.${stdenv.hostPlatform.system} or (throw "matter-linux-ota-provider: unsupported system ${stdenv.hostPlatform.system}");
  hashes = {
    x86_64-linux = "sha256-RVDfevZSnkYgRj0cASf4MOwkBMgXrUxjQ7KeMs7AFE4=";
    aarch64-linux = "sha256-4GirbEBQ4j6qbM2pv37M3Et5KiUU4QmMvBK0FM1kqn4=";
  };
  hash = hashes.${stdenv.hostPlatform.system} or (throw "matter-linux-ota-provider: no hash for ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    pname = "matter-linux-ota-provider";
    inherit version;

    src = fetchurl {
      url = "https://github.com/home-assistant-libs/matter-linux-ota-provider/releases/download/${version}/${binName}";
      inherit hash;
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib libnl];

    dontUnpack = true;

    installPhase = ''
      install -D -m 0555 $src $out/bin/chip-ota-provider-app
    '';

    meta = with lib; {
      description = "Matter OTA Provider app (chip-ota-provider-app) for python-matter-server firmware updates";
      homepage = "https://github.com/home-assistant-libs/matter-linux-ota-provider";
      license = licenses.asl20;
      maintainers = [];
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
