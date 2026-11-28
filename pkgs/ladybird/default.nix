{
  ladybird,
  mesa,
  closureInfo,
  symlinkJoin,
  makeWrapper,
  callPackage,
}:
let
  # Drivers dlopen dependencies after Landlock is installed. Keep the permitted
  # library directories tied to this exact driver closure, rather than /nix/store.
  gpuClosure = closureInfo { rootPaths = [ mesa ]; };
  patched = ladybird.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./nixos-sandbox.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace Libraries/LibSandbox/GpuDriverPaths.cpp \
        --replace-fail '@nixMesaShare@' '${mesa}/share'
      while IFS= read -r dependency; do
        printf '    TRY(add_landlock_path_if_exists(paths, "%s/lib"sv, LandlockPath::Access::ReadOnly));\n' "$dependency"
      done < ${gpuClosure}/store-paths > Libraries/LibSandbox/NixGpuRuntimePaths.inc
    '';
  });
  wrapped = symlinkJoin {
    name = "${ladybird.name}-nixos";
    paths = [ patched ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      # Match Vulkan's discovery to the immutable manifests allowed by the patch.
      # Explicit VK_DRIVER_FILES / VK_ICD_FILENAMES remain authoritative.
      rm "$out/bin/Ladybird"
      makeWrapper ${patched}/bin/Ladybird "$out/bin/Ladybird" \
        --prefix XDG_DATA_DIRS : ${mesa}/share
    '';
    passthru = (ladybird.passthru or { }) // {
      unwrapped = patched;
      tests = {
        sandbox-fontconfig = callPackage ./test.nix { ladybird = wrapped; };
      };
    };
    inherit (ladybird) meta;
  };
in
wrapped
