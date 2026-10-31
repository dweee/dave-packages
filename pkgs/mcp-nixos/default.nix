{ pkgs, upstream }:
(upstream.lib.mkMcpNixos {
  inherit pkgs;
  python3Packages = import ./python.nix { inherit pkgs upstream; };
}).overridePythonAttrs
  (old: {
    patches = (old.patches or [ ]) ++ [ ./store-path-validation.patch ];
  })
