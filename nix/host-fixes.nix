final: prev: {
  # Vendored redlib (a4d36e95 + named MAIN FEEDS). See pkgs/redlib and
  # docs/superpowers/specs/2026-08-12-redlib-named-feeds-design.md.
  redlib = prev.callPackage ../pkgs/redlib { };

  # dorion 6.13.2 builds webkitgtk_4_1 with enableExperimental (WebRTC/WebXR),
  # and experimental flips WebKit's USE_VULKAN on; its cmake then hard-requires
  # volk (zeux/volk, the Vulkan meta-loader), which the nixpkgs expression
  # never adds (2.54.x, still absent on master). Without it webkitgtk fails to
  # configure — and nothing caches the experimental variant anyway (hydra only
  # builds the default). Note: pkgs.volk is GNU Radio's unrelated "Vector
  # Optimized Library of Kernels"; the Vulkan one is vulkan-volk. Only the
  # experimental variant is touched, so the hydra-built default webkitgtk_4_1
  # drv — and its cache hits for every other consumer — stay byte-identical.
  # volk.h also includes Vulkan SDK headers; volk's output does not propagate
  # vulkan-headers, so WebKit's WebProcess compilation needs it explicitly.
  # Drop when nixpkgs adds both inputs under enableExperimental.
  dorion = prev.dorion.override {
    webkitgtk_4_1 = (prev.webkitgtk_4_1.override { enableExperimental = true; }).overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [
        final.vulkan-volk
        final.vulkan-headers
      ];
    });
  };
}
