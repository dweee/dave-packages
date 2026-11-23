# nix-darwin: a stub. Hookshot builds for x86-64 Windows and Linux only; the options exist so a configuration shared
# with Linux hosts evaluates, and turning them on says why it cannot work yet.
self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.hookshot;
in
{
  options.programs.hookshot = {
    enable = lib.mkEnableOption "Hookshot (not supported on macOS yet)";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The Hookshot package, once there is a macOS build.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = false;
        message = "programs.hookshot: Hookshot has no macOS build yet (the game is recompiled for x86-64 Windows and Linux).";
      }
    ];
  };
}
