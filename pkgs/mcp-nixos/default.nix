{
  pkgs,
  upstream,
}:
let
  # Newer nixpkgs derives mcp-types' version and source from `mcp`, while mcp
  # depends on mcp-types in the same fixpoint. mcp-nixos' FastMCP 4 extension
  # inspects those versions to decide whether to keep the consumer's pair, so
  # that inspection recurses. Pin the pair's metadata from the pre-extension
  # set: the versions and sources still come from nixpkgs, but they no longer
  # route through the extension's own attributes.
  python3Packages = pkgs.python3Packages.overrideScope (
    _pyFinal: pyPrev: {
      mcp-types = pyPrev.mcp-types.overrideAttrs (_old: {
        inherit (pyPrev.mcp) version src;
      });
    }
  );
in
(upstream.lib.mkMcpNixos { inherit pkgs python3Packages; }).overridePythonAttrs
  (old: { patches = (old.patches or [ ]) ++ [ ./store-path-validation.patch ]; })
