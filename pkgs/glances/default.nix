{ lib, fetchFromGitHub, python3Packages, glances }:
# Backport of nixpkgs 1ae7f1bd54 (glances 4.5.7 -> 4.5.9) until it reaches
# nixos-unstable. 4.5.9 replaces python-jose, which nixpkgs marks insecure
# (CVE-2026-120459, 9029e892d6), with pyjwt. Drop once the aligned nixpkgs pin
# carries glances >= 4.5.9. Offered on x86_64-linux only: its consumers (Flakey terra
# and faeri) are x86_64, and the aarch64-linux build failed in the tested gate.
glances.overridePythonAttrs (old:
  assert lib.versionOlder old.version "4.5.9";
  {
    version = "4.5.9";
    src = fetchFromGitHub {
      owner = "nicolargo";
      repo = "glances";
      tag = "v4.5.9";
      hash = "sha256-CvT9GQ29xXTVxC7V2nGmfDhHLsAtF61+XMMLG8cmHww=";
    };
    dependencies =
      builtins.filter (p: (p.pname or "") != "python-jose") old.dependencies
      ++ [ python3Packages.pyjwt ];
    nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ python3Packages.pysmart ];
  })
