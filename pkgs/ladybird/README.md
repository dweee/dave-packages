# Ladybird on NixOS

This Linux override keeps Ladybird's Landlock and seccomp sandboxes enabled.
The compositor loads the Fontconfig rules before filesystem confinement, so
system and user hinting preferences remain available during text rasterization.
GPU initialization stays after Landlock: the package grants read-only access to
library directories in its exact Mesa closure and to the corresponding Vulkan
manifests. The launcher adds that Mesa share directory to `XDG_DATA_DIRS`,
matching loader discovery to those permissions. Explicit `VK_*` driver choices
remain authoritative; this package does not add permissions for an arbitrary
external driver closure.

The package is currently exposed on x86_64-linux and uses the source and
third-party dependencies of the pinned nixpkgs Ladybird package. It does not
change rendering defaults, force a scale factor, or disable process sandboxing.

Build and run the sandbox regression:

```sh
nix build .#ladybird .#checks.x86_64-linux.ladybird-sandbox-fontconfig
nix run .#ladybird
```

The regression renders a local page with two custom Fontconfig hinting rules
using separate temporary profiles and CPU painting. It rejects Fontconfig
configuration errors and identical screenshots. CPU painting keeps this check
usable on builders without a GPU; it does not validate hardware acceleration.
Verify Vulkan separately on a GPU-equipped host, without `--force-cpu-painting`:
check the compositor for successful driver loading and an open DRM render node,
and reject Vulkan initialization errors in its log.
