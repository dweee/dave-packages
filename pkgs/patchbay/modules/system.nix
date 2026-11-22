# programs.patchbay for NixOS and nix-darwin.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  cfg = config.programs.patchbay;
  common = import ./common.nix { inherit lib cfg; };
in
{
  options.programs.patchbay = import ./options.nix { inherit lib pkgs cfg; };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = common.packages;
        inherit (common) assertions;
      }
      # NixOS has environment.sessionVariables; nix-darwin only environment.variables.
      (
        if options.environment ? sessionVariables then
          { environment.sessionVariables = common.variables; }
        else
          { environment.variables = common.variables; }
      )
    ]
  );
}
