# Build the C API packages before cargo-c installs their headers and pkg-config files.
# The default workspace also builds rice-c, a Rust wrapper requiring an already
# installed rice-proto.pc; that wrapper is not part of the C API WebKit consumes.
{ librice }:
librice.overrideAttrs (old: {
  cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [
    "--package=rice-proto"
    "--package=rice-io"
  ];
})
