{
  lib,
  packageVersion ? "0.9.4",
  stdenv,
  python3,
  src,
  disc,
  retroRewind ? null,
  wiicompiled-translator,
  retroWfcPayload ? null,
  callPackage,
}:
let
  payload = callPackage ./retro-wfc-payload.nix { payload = retroWfcPayload; };
in
assert lib.assertMsg (retroRewind == null || retroWfcPayload != null)
  "Retro Rewind requires a locally supplied PAL Retro-WFC payload (retroWfcPayload).";
stdenv.mkDerivation {
  pname = "wiicompiled-translated";
  version = packageVersion;
  inherit src;

  nativeBuildInputs = [
    wiicompiled-translator
    python3
  ];

  # Translated code is derived from the local disc.
  preferLocalBuild = true;
  allowSubstitutes = false;

  buildPhase = ''
    runHook preBuild
    mkdir -p Assets generated build/base
    cp -f ${disc}/main.dol Assets/main.dol
    cp -f ${disc}/StaticR.rel Assets/StaticR.rel

    project=$PWD/projects/mkwii/recomp.yml
    generated=$PWD/generated
    functions=$generated/functions
    metadata=$generated/base_translation_output.json
    manifest_dir=$PWD/build/base
    shards=$generated/build_shards
    translator=${wiicompiled-translator}/bin/Translator.Cli
    threads=''${NIX_BUILD_CORES:-1}
    if [ "$threads" -lt 1 ]; then threads=1; fi
    if [ "$threads" -gt 16 ]; then threads=16; fi

    entry_point=$(awk '
      /^translation:/ { in_translation = 1 }
      in_translation && /^[[:space:]]*-[[:space:]]*0[xX][0-9a-fA-F]+[[:space:]]*$/ {
        gsub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/[[:space:]]*$/, ""); print; exit
      }
    ' "$project")
    test -n "$entry_point"

    mkdir -p "$functions" "$manifest_dir"
    ${lib.optionalString (retroRewind != null) ''
      # translate-recursive reads enabled profiles from recomp.yml; Code.pul
      # must already sit at that path so the base stamp records mod patches.
      retro_root=${lib.escapeShellArg (toString retroRewind)}
      if [ ! -f "$retro_root/Binaries/Code.pul" ] && [ -f "$retro_root/RetroRewind6/Binaries/Code.pul" ]; then
        retro_root="$retro_root/RetroRewind6"
      fi
      retro_root=$(cd "$retro_root" && pwd)
      test -f "$retro_root/Binaries/Code.pul"
      stage=$PWD/PulsarPacks/completed/RetroRewind/RetroRewind6/Binaries
      mkdir -p "$stage"
      cp -f "$retro_root/Binaries/Code.pul" "$stage/Code.pul"
    ''}
    "$translator" translate-recursive "$entry_point" --project "$project" \
      --outdir "$functions" --output-metadata "$metadata" \
      --production-source-bundle "$generated/base_translation_sources.bin" \
      --no-function-files --prune-stale --threads "$threads"
    "$translator" emit-base-manifest --project "$project" --out "$manifest_dir" \
      --functions-dir "$functions" --translation-output-metadata "$metadata" --region P

    ${lib.optionalString (retroRewind != null) ''
      mod_out=$PWD/build/mods/retro_rewind_full_cpp
      "$translator" translate-mod --project "$project" --profile retro-rewind \
        --base-manifest "$manifest_dir/mkwii_base_manifest.json" \
        --base-translation-output-metadata "$metadata" \
        --code-pul "$retro_root/Binaries/Code.pul" \
        --mod-root "$retro_root" --mod-name 'Retro Rewind' --region P \
        --out "$mod_out" --prefer-cached-inputs --emit-cpp --threads "$threads" \
        --retro-wfc-payload ${payload}/binary/payload.RMCPD00.bin
    ''}

    "$translator" generate-data-init --project "$project"
    shard_args=(emit-build-shards --project "$project" --base-metadata "$metadata" \
      --base-functions-dir "$functions" --native-source-dir "$PWD/runtime/src" --out "$shards")
    ${lib.optionalString (retroRewind != null) ''
      shard_args+=(--resolved-profile "$PWD/build/mods/retro_rewind_full_cpp/resolved_dispatch_profile.json" \
        --retro-cpp-dir "$PWD/build/mods/retro_rewind_full_cpp/cpp")
    ''}
    "$translator" "''${shard_args[@]}"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    export src_root=$PWD
    cp -a generated $out/generated
    if [ -d build ]; then
      cp -a build $out/build
    fi
    python3 ${./rewrite-translated-paths.py}
    runHook postInstall
  '';

  meta = {
    description = "Translator output (generated C++) for WiiCompiled PAL RMCP01";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
