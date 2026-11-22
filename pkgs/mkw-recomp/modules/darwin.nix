# nix-darwin module: programs.mkw-recomp, a stub for when the runtime runs on macOS. Today the runtime has Linux and
# Windows platform layers only (runtime/platform/) and Vulkan would come through MoltenVK, which lacks
# VK_EXT_mesh_shader; the package builds for Linux only. The options exist so a shared configuration can import the
# module on every host; enabling it fails with that reason instead of an evaluation error elsewhere.
_self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.mkw-recomp;
in
{
  options.programs.mkw-recomp = {
    enable = lib.mkEnableOption "mkw-recomp (not supported on macOS yet)";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The mkw-recomp package, once there is a macOS build.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "programs.mkw-recomp: no macOS build yet (nix/README.md); leave it off on nix-darwin hosts.";
      }
    ];
    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;
  };
}
