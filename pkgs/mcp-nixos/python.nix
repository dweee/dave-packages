{ pkgs, upstream }:
# Python set carrying the FastMCP 4 / MCP SDK 2 stack. nixpkgs now ships mcp 2
# but fastmcp 3 (marked broken against it), so MCP servers need this set.
let
  base = pkgs.python3Packages.overrideScope (
    _: prev:
    pkgs.lib.optionalAttrs (prev ? mcp-types) {
      # nixpkgs derives mcp-types' version from the final `mcp`, so upstream's
      # fastmcp4 extension reading it while choosing `mcp` is an infinite
      # recursion. Pin it to the base set's mcp version.
      mcp-types = prev.mcp-types.overridePythonAttrs { inherit (prev.mcp) version; };
    }
  );
in
base.overrideScope (import "${upstream}/nix/fastmcp4.nix" { inherit (pkgs) lib; })
