# The Horizon packages the modules choose from: the catalog's own build when
# the module comes from the flake, else pkgs.horizonPackages (the overlay),
# else this nixpkgs' build of ../default.nix.
{ lib, pkgs, ... }:
{
  options.horizon.packageSet = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    default = pkgs.horizonPackages or (pkgs.callPackage ../default.nix { });
    defaultText = lib.literalExpression "pkgs.horizonPackages";
    description = "Every Horizon channel and variant (pkgs/horizon/default.nix).";
  };
}
