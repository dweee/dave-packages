{ pkgs, upstream }:
(upstream.lib.mkMcpNixos { inherit pkgs; }).overridePythonAttrs
(old: { patches = (old.patches or [ ]) ++ [ ./store-path-validation.patch ]; })
