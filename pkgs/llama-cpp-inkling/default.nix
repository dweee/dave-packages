# Reuse upstream packaging, with the modern Darwin SDK and no unused web UI closure.
{
  pkgs,
  upstream,
  useVulkan ? false,
}:
let
  inherit (pkgs) lib;
  runtime = pkgs.callPackage "${upstream}/.devops/nix/package.nix" {
    inherit useVulkan;
    llamaVersion = "b12600";
    useWebUi = false;
    # Modern Darwin stdenv propagates its SDK; upstream still references legacy frameworks.
    darwin = pkgs.darwin // {
      apple_sdk.frameworks = lib.genAttrs [ "Accelerate" "CoreVideo" "CoreGraphics" "MetalKit" ] (
        _: pkgs.apple-sdk
      );
    };
  };
in
runtime.overrideAttrs (old: {
  # Structured derivation attributes otherwise retain the disabled UI and its npm graph.
  webui = null;
  cmakeFlags =
    old.cmakeFlags
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      (lib.cmakeBool "GGML_CPU_ALL_VARIANTS" true)
      (lib.cmakeBool "GGML_BACKEND_DL" true)
      (lib.cmakeFeature "GGML_BACKEND_DIR" "${builtins.placeholder "out"}/lib")
    ];
})
