{ pkgs }:
let
  desktop = import ./freebsd-desktop.nix;
  server = import ./freebsd-server.nix;

  # Keep this compatibility fixture aligned with NixBSD's supported nixpkgs
  # revision. Consumers import the overlays using their own package set.
  compatSource = builtins.fetchTarball {
    url = "https://releases.nixos.org/nixos/unstable-small/nixos-26.11pre1040699.7d4b60cc1654/nixexprs.tar.xz";
    sha256 = "sha256-ARPrbHm5ReO4qHnxnIut1gGDz68gl2vyzUFTHenThz4=";
  };
  lib = import (compatSource + "/lib");
  freebsd = import compatSource {
    localSystem = "x86_64-linux";
    crossSystem = lib.systems.examples.x86_64-freebsd;
    config = { };
    overlays = [
      desktop
      server
    ];
  };
  names = builtins.attrNames (desktop freebsd freebsd // server freebsd freebsd) ++ [ "sway" ];
  drvPaths = map (name: freebsd.${name}.drvPath) names;
in
assert desktop pkgs pkgs == { };
assert server pkgs pkgs == { };
assert
  pkgs.stdenv.hostPlatform.system != "x86_64-linux"
  || (
    freebsd.stdenv.hostPlatform.isFreeBSD
    && freebsd.mesa.pname == "mesa-freebsd-softpipe"
    && builtins.deepSeq drvPaths true
  );
pkgs.runCommand "freebsd-overlays-check" { } ''
  touch "$out"
''
