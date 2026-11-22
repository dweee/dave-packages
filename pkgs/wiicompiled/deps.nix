# Prefetched aurora FetchContent trees so a sandboxed native game build never
# hits the network. Versions match aurora-main/CMakeLists.txt and
# aurora-main/extern/CMakeLists.txt. Hashes are unpacked (fetchzip).
{
  lib,
  stdenv,
  fetchzip,
}:
let
  inherit (stdenv.hostPlatform) system;

  # Match the frozen Aurora submodule's encounter/dawn release.
  # Archives are flat install trees (fetchzip stripRoot = false).
  # Published raw asset digests were verified before unpacked NAR hashing.
  dawnSources = {
    x86_64-linux = {
      url = "https://github.com/encounter/dawn/releases/download/v20260807.225922/dawn-linux-x86_64.tar.gz";
      hash = "sha256-deRtiZ221q6PO9zejJBwa56fCM63KEh6y2p7nM+MOYU=";
      stripRoot = false;
    };
    aarch64-linux = {
      url = "https://github.com/encounter/dawn/releases/download/v20260807.225922/dawn-linux-aarch64.tar.gz";
      hash = "sha256-WUs7dDxNbQtt5x8AIDmVuFWhcZVgSyUUuRJvr5yrREo=";
      stripRoot = false;
    };
    aarch64-darwin = {
      url = "https://github.com/encounter/dawn/releases/download/v20260807.225922/dawn-darwin-arm64.tar.gz";
      hash = "sha256-pM15OoUdHZ84Y9iORsvgahE6FzvQFOtjry0nNWvIqHo=";
      stripRoot = false;
    };
    x86_64-darwin = {
      url = "https://github.com/encounter/dawn/releases/download/v20260807.225922/dawn-darwin-x86_64.tar.gz";
      hash = "sha256-4qDs7eeEw89oEr37H5/vpjLHWaZf8216flaLmhyx5GY=";
      stripRoot = false;
    };
  };

  dawn = dawnSources.${system} or (throw "wiicompiled: no prebuilt Dawn package for ${system}");

  mk =
    url: hash:
    fetchzip {
      inherit url hash;
    };
in
rec {
  sdl = mk "https://github.com/libsdl-org/SDL/archive/refs/tags/release-3.4.10.tar.gz" "sha256-6Dph2eLiJUmpQzPWe8EuY5LrWhrFwde2f2dwfgCcWNw=";
  imgui = mk "https://github.com/ocornut/imgui/archive/refs/tags/v1.91.9b-docking.tar.gz" "sha256-mQOJ6jCN+7VopgZ61yzaCnt4R1QLrW7+47xxMhFRHLQ=";
  tracy = mk "https://github.com/wolfpld/tracy/archive/refs/tags/v0.14.1.zip" "sha256-vcLI9jb7eYcR162LgBQ2P4A0oiZuYRfYRQiDhlAk5TI=";
  abseil = mk "https://github.com/abseil/abseil-cpp/archive/refs/tags/20240722.0.tar.gz" "sha256-51jpDhdZ0n+KLmxh8KVaTz53pZAB0dHjmILFX+OLud4=";
  fmt = mk "https://github.com/fmtlib/fmt/archive/refs/tags/12.1.0.tar.gz" "sha256-ZmI1Dv0ZabPlxa02OpERI47jp7zFfjpeWCy1WyuPYZ0=";
  xxhash = mk "https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.4.tar.gz" "sha256-YbWK23lU2/DiKQFPWioMHLgEt8vBtDpjBakT9ds3XpI=";
  zlib = mk "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.3.3.tar.gz" "sha256-6GlHCnx9dQtmViPnvHnMS+l9Z+g6M8ynrSxLhLtmAKU=";
  libpng = mk "https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.58.tar.gz" "sha256-JSdzPsfRBjnk8DB/fkOCkaiUJ9/neQ2myIK5xnQuSsM=";
  freetype = mk "https://files.twilitrealm.dev/freetype-2.14.3.tar.gz" "sha256-AQKiXuGitV2OM650gwybyrApUi3s+D+EX4faoxPAQDg=";
  zstd = mk "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz" "sha256-tNFWIT9ydfozB8dWcmTMuZLCQmQudTFJIkSr0aG7S44=";
  sqlite3 = mk "https://sqlite.org/2026/sqlite-amalgamation-3510300.zip" "sha256-pNMR8zxaaqfAzQ0AQBOXMct4usdjey1Q0Gnitg06UhM=";
  # Matches runtime/cmake/MbedTLSPin.cmake. The upstream raw archive hash was
  # checked before deriving this unpacked NAR hash.
  mbedtls = mk "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.7/mbedtls-3.6.7.tar.bz2" "sha256-t1ZPeFA3ftKaEIaXQ7RXZEsiOAYK4KSSm55SFr9g17A=";
  dawnPrebuilt = fetchzip (
    {
      inherit (dawn) url hash;
    }
    // lib.optionalAttrs (!(dawn.stripRoot or true)) {
      stripRoot = false;
    }
  );

  # Names match FetchContent_Declare() identifiers (CMake uppercases them).
  cmakeFlags = [
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DCMAKE_POLICY_DEFAULT_CMP0168=NEW"
    "-DAURORA_DAWN_PROVIDER=package"
    "-DAURORA_SDL3_PROVIDER=vendor"
    "-DFETCHCONTENT_SOURCE_DIR_DAWN_PREBUILT=${dawnPrebuilt}"
    "-DFETCHCONTENT_SOURCE_DIR_SDL=${sdl}"
    "-DFETCHCONTENT_SOURCE_DIR_IMGUI=${imgui}"
    "-DFETCHCONTENT_SOURCE_DIR_TRACY=${tracy}"
    "-DFETCHCONTENT_SOURCE_DIR_ABSEIL-CPP=${abseil}"
    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmt}"
    "-DFETCHCONTENT_SOURCE_DIR_XXHASH=${xxhash}"
    "-DFETCHCONTENT_SOURCE_DIR_ZLIB=${zlib}"
    "-DFETCHCONTENT_SOURCE_DIR_PNG=${libpng}"
    "-DFETCHCONTENT_SOURCE_DIR_FREETYPE=${freetype}"
    "-DFETCHCONTENT_SOURCE_DIR_ZSTD=${zstd}"
    "-DFETCHCONTENT_SOURCE_DIR_SQLITE3=${sqlite3}"
    "-DFETCHCONTENT_SOURCE_DIR_MKW_MBEDTLS_UPSTREAM=${mbedtls}"
  ];
}
