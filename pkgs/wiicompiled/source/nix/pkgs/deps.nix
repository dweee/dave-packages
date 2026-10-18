# Prefetched aurora FetchContent trees so a sandboxed native game build never
# hits the network. Versions match aurora-main/CMakeLists.txt and
# aurora-main/extern/CMakeLists.txt. Hashes are unpacked (fetchzip).
{
  lib,
  stdenv,
  fetchzip,
}: let
  inherit (stdenv.hostPlatform) system;

  # v0.2.32 switched Aurora from encounter/dawn-build to theofficialgman.
  # Those archives are flat install trees (fetchzip stripRoot = false). CMake
  # URL_HASH is the tarball SHA256; these hashes are the unpacked NAR.
  dawnSources = {
    x86_64-linux = {
      url = "https://github.com/theofficialgman/dawn-build/releases/download/v20260603.191052/dawn-linux-x86_64.tar.gz";
      hash = "sha256-aMAe/uvxuP2YYios3uw/PE1pGgQanHoEvpOsEUa+MxI=";
      stripRoot = false;
    };
    aarch64-linux = {
      url = "https://github.com/theofficialgman/dawn-build/releases/download/v20260603.191052/dawn-linux-aarch64.tar.gz";
      hash = "sha256-3bnRTV/IINxBt1k7aREMJEqtJX2kkKsT2VN18t9x9m0=";
      stripRoot = false;
    };
    aarch64-darwin = {
      url = "https://github.com/theofficialgman/dawn-build/releases/download/v20260603.191052/dawn-darwin-arm64.tar.gz";
      hash = "sha256-NhpP8RMnF3OAOyUBneMQhx5iQm9CLEpGe8U6bRn8GpU=";
      stripRoot = false;
    };
    x86_64-darwin = {
      url = "https://github.com/theofficialgman/dawn-build/releases/download/v20260603.191052/dawn-darwin-x86_64.tar.gz";
      hash = "sha256-dn/a5YowpteEBGl3UiXuQgOBIcP+yIOGBhEBWI+bYmU=";
      stripRoot = false;
    };
  };

  dawn =
    dawnSources.${system}
    or (throw "wiicompiled: no prebuilt Dawn package for ${system}");

  mk = url: hash:
    fetchzip {
      inherit url hash;
    };
in rec {
  sdl = mk "https://github.com/libsdl-org/SDL/releases/download/release-3.4.4/SDL3-3.4.4.tar.gz" "sha256-jTeWYpFwYvtH7OMRlyR9KiKDFdf9plOOvMGl7Hzsi7I=";
  imgui = mk "https://github.com/ocornut/imgui/archive/refs/tags/v1.91.9b-docking.tar.gz" "sha256-mQOJ6jCN+7VopgZ61yzaCnt4R1QLrW7+47xxMhFRHLQ=";
  tracy = mk "https://github.com/wolfpld/tracy/archive/a64b9a20294d59421a2f57aeca3c6383d8c48169.tar.gz" "sha256-hbNGOsGeyGSvCJ2No8RkwOib1lX2on3vNZSzyVkZdXw=";
  abseil = mk "https://github.com/abseil/abseil-cpp/archive/refs/tags/20240722.0.tar.gz" "sha256-51jpDhdZ0n+KLmxh8KVaTz53pZAB0dHjmILFX+OLud4=";
  fmt = mk "https://github.com/fmtlib/fmt/archive/refs/tags/11.1.4.tar.gz" "sha256-sUbxlYi/Aupaox3JjWFqXIjcaQa0LFjclQAOleT+FRA=";
  xxhash = mk "https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.3.tar.gz" "sha256-h6kohM+NxvQ89R9NEXZcYBG2wPOuB4mcyPfofKrx9wQ=";
  zlib = mk "https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz" "sha256-tKLefmGqB2HVUMILJ7Gqa0v9GH7fqv64d5S5kK1tcYU=";
  libpng = mk "https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.58.tar.gz" "sha256-JSdzPsfRBjnk8DB/fkOCkaiUJ9/neQ2myIK5xnQuSsM=";
  freetype = mk "https://files.twilitrealm.dev/freetype-2.14.3.tar.gz" "sha256-AQKiXuGitV2OM650gwybyrApUi3s+D+EX4faoxPAQDg=";
  zstd = mk "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz" "sha256-tNFWIT9ydfozB8dWcmTMuZLCQmQudTFJIkSr0aG7S44=";
  sqlite3 = mk "https://sqlite.org/2026/sqlite-amalgamation-3510300.zip" "sha256-pNMR8zxaaqfAzQ0AQBOXMct4usdjey1Q0Gnitg06UhM=";
  dawnPrebuilt = fetchzip ({
      inherit (dawn) url hash;
    }
    // lib.optionalAttrs (!(dawn.stripRoot or true)) {
      stripRoot = false;
    });

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
  ];
}
