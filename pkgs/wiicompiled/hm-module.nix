catalog:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = import ./module-common.nix {
    inherit
      catalog
      lib
      pkgs
      config
      ;
  };
in
{
  options.programs.wiicompiled = import ./options.nix { inherit lib; };

  config = lib.mkIf common.cfg.enable {
    # Packages come from pkgs.extend in module-common.nix so this works with
    # both standalone HM and useGlobalPkgs (which forbids nixpkgs.overlays here).
    home.packages = common.wiiPackages;
    assertions = common.assertions;
  };
}
